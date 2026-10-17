import asyncio
import base64
import binascii
import logging
import re
from io import BytesIO
from typing import Any

import easyocr
import numpy as np
from PIL import Image, ImageOps, ImageEnhance, ImageFilter
from fastapi import FastAPI, File, HTTPException, UploadFile, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from ultralytics import YOLO

logging.basicConfig(level=logging.INFO)
log = logging.getLogger("trulyabled-backend")

app = FastAPI(
    title="TrulyAbled Combined AI Backend",
    description="Object detection over WebSocket and Indian banknote OCR over HTTP.",
    version="1.1.0",
)

# Development configuration. Restrict allowed origins before deploying publicly.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["*"],
)

# Load YOLO once when the API process starts. The first run may download yolov8n.pt.
try:
    object_model = YOLO("yolov8n.pt")
    log.info("YOLO object detection model loaded.")
except Exception:
    log.exception("Could not load YOLO model. Object detection endpoints will fail.")
    object_model = None

# Lazy-load EasyOCR when currency recognition is first requested.
ocr_reader = None
ocr_lock = asyncio.Lock()
yolo_lock = asyncio.Lock()

HAZARD_LABELS = {
    "person", "bicycle", "car", "motorcycle", "bus", "truck",
    "traffic light", "stop sign", "train",
}
VALID_INR_DENOMINATIONS = {10, 20, 50, 100, 200, 500, 2000}
MAX_UPLOAD_BYTES = 12 * 1024 * 1024


def get_ocr_reader():
    global ocr_reader
    if ocr_reader is None:
        # EasyOCR downloads weights on first use; internet is needed initially.
        ocr_reader = easyocr.Reader(["en"], gpu=False)
    return ocr_reader


def decode_base64_image(message: str) -> np.ndarray:
    """Decode a plain base64 image or a data:image/...;base64,... message."""
    try:
        payload = message.split(",", 1)[1] if message.startswith("data:") else message
        raw = base64.b64decode(payload, validate=True)
        image = Image.open(BytesIO(raw))
        image = ImageOps.exif_transpose(image).convert("RGB")
        image.thumbnail((1280, 1280))
        return np.asarray(image)
    except (binascii.Error, ValueError, OSError, IndexError) as exc:
        raise ValueError(f"Invalid base64 image: {exc}") from exc


def relative_size_label(box_height_fraction: float) -> str:
    """Image-size hint only; this is not a distance measurement in metres."""
    if box_height_fraction >= 0.55:
        return "very prominent in view"
    if box_height_fraction >= 0.28:
        return "near-looking"
    if box_height_fraction >= 0.12:
        return "mid-sized in view"
    return "far-looking or small in view"


def normalize_ocr_text(text: str) -> str:
    text = str(text).upper()
    # Common OCR confusions in currency labels: O->0, I/L->1, S->5.
    # Only use these substitutions in denomination-like matching, not displayed text.
    return re.sub(r"\s+", " ", text).strip()


def _text_candidates(text: str, ocr_confidence: float) -> list[tuple[int, float, bool]]:
    """Extract likely denominations, preferring amounts near currency wording."""
    original = normalize_ocr_text(text)
    compact = original.replace(",", "")
    upper = compact.upper()
    currency_context = bool(re.search(r"₹|\bRS\.?\b|\bINR\b|RUPEE", upper))

    # First look for explicit currency context, e.g. 'Rs 500', '₹500', '500 rupees'.
    patterns = [
        r"(?:₹|RS\.?\s*|INR\s*)(2000|500|200|100|50|20|10)\b",
        r"\b(2000|500|200|100|50|20|10)\s*(?:RUPEES?|INR)\b",
    ]
    found: list[tuple[int, float, bool]] = []
    for pattern in patterns:
        for match in re.finditer(pattern, upper, flags=re.IGNORECASE):
            value = int(match.group(1))
            if value in VALID_INR_DENOMINATIONS:
                score = max(0.0, min(1.0, float(ocr_confidence)))
                found.append((value, min(1.0, score + 0.25), True))

    if found:
        return found

    # OCR sometimes reads the note's large printed '₹500' as just '500'.
    # Use a conservative bare-number fallback; serial numbers can still confuse it.
    digit_text = re.sub(r"(?<=\d)[, ](?=\d)", "", upper)
    for match in re.finditer(r"(?<!\d)(2000|500|200|100|50|20|10)(?!\d)", digit_text):
        value = int(match.group(1))
        if value in VALID_INR_DENOMINATIONS:
            score = max(0.0, min(1.0, float(ocr_confidence)))
            # Bare numbers receive a penalty because they might be serial numbers.
            score *= 0.55
            found.append((value, score, False))
    return found


def extract_denomination(ocr_results: list[Any]) -> tuple[int | None, float, list[str]]:
    """Heuristic OCR extraction; not a trained banknote classifier."""
    candidates: list[tuple[int, float, bool]] = []
    recognized_text: list[str] = []

    for item in ocr_results:
        if len(item) < 2:
            continue
        text = str(item[1]).strip()
        recognized_text.append(text)
        confidence = float(item[2]) if len(item) > 2 else 0.4
        candidates.extend(_text_candidates(text, confidence))

    if not candidates:
        return None, 0.0, recognized_text

    # Aggregate by denomination. Explicit currency-context matches dominate bare numbers.
    totals: dict[int, float] = {}
    counts: dict[int, int] = {}
    explicit_hits: dict[int, int] = {}
    for value, score, explicit in candidates:
        totals[value] = totals.get(value, 0.0) + score
        counts[value] = counts.get(value, 0) + 1
        if explicit:
            explicit_hits[value] = explicit_hits.get(value, 0) + 1

    winner = max(
        totals,
        key=lambda value: (
            explicit_hits.get(value, 0),
            totals[value],
            counts[value],
        ),
    )
    score = min(1.0, totals[winner] / max(1, counts[winner]))
    return winner, score, recognized_text


def prepare_ocr_images(image: Image.Image) -> list[np.ndarray]:
    """Create original and contrast-enhanced variants to improve OCR recall."""
    rgb = image.convert("RGB")
    variants = [rgb]
    # Upscale small images while preserving reasonable memory usage.
    if max(rgb.size) < 1400:
        scale = min(2.0, 1400 / max(rgb.size))
        rgb = rgb.resize((int(rgb.width * scale), int(rgb.height * scale)), Image.Resampling.LANCZOS)
        variants.append(rgb)
    enhanced = ImageEnhance.Contrast(rgb).enhance(1.5)
    enhanced = ImageEnhance.Sharpness(enhanced).enhance(1.4)
    variants.append(enhanced.filter(ImageFilter.UnsharpMask(radius=1, percent=120, threshold=3)))
    # Avoid duplicate arrays for identical dimensions/content where possible.
    return [np.asarray(variant) for variant in variants]


@app.get("/")
async def root():
    return {
        "service": "TrulyAbled Combined AI Backend",
        "endpoints": {
            "health": "/health",
            "object_detection_websocket": "/ws/detect",
            "currency_prediction": "POST /predict",
            "docs": "/docs",
        },
    }


@app.get("/health")
async def health():
    return {
        "status": "ok",
        "object_detection": {"available": object_model is not None, "model": "yolov8n.pt"},
        "currency_recognition": {
            "available": True,
            "method": "EasyOCR with image preprocessing and denomination-text heuristic",
            "authenticity_verification": False,
        },
    }


@app.websocket("/ws/detect")
async def object_detection_websocket(websocket: WebSocket):
    """Accept base64 image frames and return detected objects as JSON."""
    await websocket.accept()
    log.info("Object-detection WebSocket connected")
    if object_model is None:
        await websocket.send_json({
            "error": "YOLO model did not load. Check backend logs and model download.",
            "objects": [],
        })
        await websocket.close(code=1011)
        return

    try:
        while True:
            message = await websocket.receive_text()
            try:
                frame = decode_base64_image(message)
                async with yolo_lock:
                    results = await asyncio.to_thread(
                        object_model.predict,
                        source=frame,
                        conf=0.35,
                        imgsz=640,
                        max_det=15,
                        verbose=False,
                    )

                height, width = frame.shape[:2]
                objects = []
                for result in results:
                    if result.boxes is None:
                        continue
                    for box in result.boxes:
                        cls_id = int(box.cls[0].item())
                        name = str(result.names.get(cls_id, cls_id))
                        confidence = float(box.conf[0].item())
                        x1, y1, x2, y2 = [float(value) for value in box.xyxy[0].tolist()]
                        box_height_fraction = max(0.0, y2 - y1) / max(height, 1)
                        objects.append({
                            "name": name,
                            "confidence": round(confidence, 4),
                            "bbox": {
                                "x1": round(x1 / max(width, 1), 4),
                                "y1": round(y1 / max(height, 1), 4),
                                "x2": round(x2 / max(width, 1), 4),
                                "y2": round(y2 / max(height, 1), 4),
                            },
                            "distance_label": relative_size_label(box_height_fraction),
                            "hazard": name in HAZARD_LABELS,
                        })
                objects.sort(key=lambda item: item["confidence"], reverse=True)
                await websocket.send_json({
                    "objects": objects,
                    "note": "Distance label is image-size heuristic, not metres.",
                })
            except ValueError as exc:
                await websocket.send_json({"error": str(exc), "objects": []})
            except Exception:
                log.exception("Object detection failed for a frame")
                await websocket.send_json({"error": "Object detection failed for this frame.", "objects": []})
    except WebSocketDisconnect:
        log.info("Object-detection WebSocket disconnected")
    except Exception:
        log.exception("Object-detection WebSocket failed")
        try:
            await websocket.close(code=1011)
        except Exception:
            pass


@app.post("/predict")
async def currency_prediction(file: UploadFile = File(...)):
    """Read visible denomination text from an uploaded banknote image."""
    # Do not reject based on Content-Type: Flutter web / image_picker may send
    # application/octet-stream. Validate the actual bytes with Pillow below.

    raw = await file.read()
    if not raw:
        raise HTTPException(status_code=400, detail="The uploaded image is empty.")
    if len(raw) > MAX_UPLOAD_BYTES:
        raise HTTPException(status_code=413, detail="Image must be 12 MB or smaller.")

    try:
        image = Image.open(BytesIO(raw))
        image = ImageOps.exif_transpose(image).convert("RGB")
        image.thumbnail((1600, 1600), Image.Resampling.LANCZOS)
    except Exception as exc:
        raise HTTPException(status_code=400, detail="Could not read the image. Try a JPG or PNG.") from exc

    try:
        async with ocr_lock:
            reader = await asyncio.to_thread(get_ocr_reader)
            combined_results = []
            # Run OCR on several variants; use all evidence when deciding denomination.
            for image_array in prepare_ocr_images(image):
                results = await asyncio.to_thread(
                    reader.readtext,
                    image_array,
                    detail=1,
                    paragraph=False,
                    decoder="greedy",
                )
                combined_results.extend(results)
        value, score, recognized_text = extract_denomination(combined_results)
    except Exception as exc:
        log.exception("Currency OCR failed")
        raise HTTPException(
            status_code=500,
            detail="Currency OCR failed. Check backend logs and EasyOCR model setup.",
        ) from exc

    if value is None:
        return {
            "label": "Unable to identify denomination",
            "denomination": None,
            "currency": "INR",
            "confidence": 0.0,
            "details": "No clear denomination was identified. Upload a sharp, well-lit photo with the full banknote visible and minimal glare.",
            "recognized_text": recognized_text[:30],
            "authenticity_verified": False,
        }

    return {
        "label": f"Indian Rupees - ₹{value}",
        "denomination": value,
        "currency": "INR",
        "confidence": round(score, 3),
        "details": f"Likely denomination: ₹{value}. This is an OCR estimate, not banknote authentication; printed serial numbers or other text may cause mistakes.",
        "recognized_text": recognized_text[:30],
        "authenticity_verified": False,
    }
