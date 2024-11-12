from flask import Flask, request, jsonify
import cv2
import os
import numpy as np
import tensorflow as tf  # For loading the TFLite model

app = Flask(__name__)

# Load TFLite model
interpreter = tf.lite.Interpreter(model_path="model_unquant.tflite")
interpreter.allocate_tensors()

# Get input and output details for the model
input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()

def process_frame(frame):
    # Preprocess the frame to match the model's expected input
    input_shape = input_details[0]['shape'][1:3]  # Get expected width and height
    frame_resized = cv2.resize(frame, (input_shape[1], input_shape[0]))
    input_data = np.expand_dims(frame_resized, axis=0).astype(np.float32)

    # Set the tensor to the input
    interpreter.set_tensor(input_details[0]['index'], input_data)
    interpreter.invoke()

    # Get the output tensor
    output_data = interpreter.get_tensor(output_details[0]['index'])
    
    # Extract confidence score (assuming the output provides it)
    confidence_score = float(output_data[0][0])  # Adjust based on model's output structure
    return confidence_score

def process_video(video_path):
    cap = cv2.VideoCapture(video_path)
    confidence_scores = []
    
    # Process each frame and accumulate confidence scores
    while cap.isOpened():
        ret, frame = cap.read()
        if not ret:
            break
        confidence_score = process_frame(frame)
        confidence_scores.append(confidence_score)
    
    cap.release()
    
    # Calculate the average confidence score across frames
    avg_confidence = np.mean(confidence_scores) if confidence_scores else 0.0
    label = "Familiar"  # Replace with actual label if available or model-specific
    
    # Return a single result for the entire video
    return {"label": label, "confidence": avg_confidence}

@app.route('/detect_video', methods=['POST'])
def detect_video():
    if 'video' not in request.files:
        return jsonify({"error": "No video file provided"}), 400

    video_file = request.files['video']
    video_path = f"./temp_{video_file.filename}"
    video_file.save(video_path)

    try:
        result = process_video(video_path)
        os.remove(video_path)  # Cleanup the temporary video file
        return jsonify(result), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
