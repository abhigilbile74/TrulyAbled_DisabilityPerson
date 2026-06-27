from ultralytics import YOLO
import cv2

model = YOLO("ai/models/yolov8.pt")


def detect_objects(image_path):

    image = cv2.imread(image_path)

    results = model(image)

    detected = []

    for result in results:

        boxes = result.boxes

        for box in boxes:

            cls = int(box.cls[0])

            confidence = float(box.conf[0])

            label = model.names[cls]

            detected.append({
                "label": label,
                "confidence": round(confidence, 2)
            })

    return detected