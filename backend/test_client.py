import asyncio
import websockets
import cv2
import base64

async def live_test():
    uri = "ws://127.0.0.1:8000/ws/detect"

    async with websockets.connect(uri) as websocket:

        cap = cv2.VideoCapture(0)

        while True:
            ret, frame = cap.read()
            if not ret:
                break

            _, buffer = cv2.imencode(".jpg", frame, [cv2.IMWRITE_JPEG_QUALITY, 60])

            image_base64 = base64.b64encode(buffer).decode()

            await websocket.send(image_base64)

            result = await websocket.recv()

            print(result)

            cv2.imshow("Webcam", frame)

            if cv2.waitKey(1) & 0xFF == ord("q"):
                break

        cap.release()
        cv2.destroyAllWindows()

asyncio.run(live_test())