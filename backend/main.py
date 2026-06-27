from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from ultralytics import YOLO
import cv2
import numpy as np
import base64

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

model = YOLO("yolov8n.pt")

@app.get("/")
async def root():
    return {"status": "running"}

@app.websocket("/ws/detect")
async def detect(websocket: WebSocket):
    print("Incomming conn....")
    await websocket.accept()
    print("client connected ")

    try:
        while True:

            frame = await websocket.receive_text()

            image_bytes = base64.b64decode(frame)

            image = cv2.imdecode(
                np.frombuffer(image_bytes, np.uint8),
                cv2.IMREAD_COLOR,
            )

            if image is None:
                continue

            results = model(image, verbose=False)

            detected = []

            for result in results:
                for box in result.boxes:

                    confidence = float(box.conf[0])

                    if confidence < 0.50:
                        continue

                    cls = int(box.cls[0])

                    detected.append({
                        "name": model.names[cls],
                        "confidence": round(confidence, 2),
                    })

            await websocket.send_json({
                "objects": detected
            })

    except WebSocketDisconnect:
        print("Client disconnected")



