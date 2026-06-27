import os

from fastapi import APIRouter, UploadFile, File

from ai.object_detection.detector import detect_objects

router = APIRouter()

UPLOAD_FOLDER = "uploads"

os.makedirs(UPLOAD_FOLDER, exist_ok=True)


@router.post("/detect")
async def detect(file: UploadFile = File(...)):

    path = os.path.join(UPLOAD_FOLDER, file.filename)

    with open(path, "wb") as f:
        f.write(await file.read())

    result = detect_objects(path)

    os.remove(path)

    return {
        "success": True,
        "objects": result
    }

