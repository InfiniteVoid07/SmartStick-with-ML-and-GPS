import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart'; // Add video player package
import 'dart:convert';

class VideoDetectionPage extends StatefulWidget {
  @override
  _VideoDetectionPageState createState() => _VideoDetectionPageState();
}

class _VideoDetectionPageState extends State<VideoDetectionPage> {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  final ImagePicker _picker = ImagePicker();
  File? _selectedVideo;
  VideoPlayerController? _videoController;
  bool _isVideoPlaying = false;
  String _apiResponse = ""; // Store the API response to display

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    _cameras = await availableCameras();
    _controller = CameraController(_cameras[0], ResolutionPreset.high);
    await _controller!.initialize();
    setState(() {
      _isCameraInitialized = true;
    });
  }

  Future<void> _pickVideoFromGallery() async {
    final pickedFile = await _picker.pickVideo(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedVideo = File(pickedFile.path);
        _apiResponse = "Processing video..."; // Update UI with a status message
      });

      // Initialize video player controller for preview
      _videoController = VideoPlayerController.file(_selectedVideo!)
        ..initialize().then((_) {
          setState(() {});
        });

      await _sendVideoToApi(_selectedVideo!);
    }
  }

  Future<void> _sendVideoToApi(File videoFile) async {
    final uri = Uri.parse(
        'http://10.0.2.2:5000/detect_video'); // Adjust to match your API URL
    final request = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('video', videoFile.path));

    try {
      final response = await request.send();
      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final result = jsonDecode(responseData); // Assuming JSON response

        final label = result['label'];
        final confidence = result['confidence'];

        setState(() {
          _apiResponse =
              "Detection result: $label with confidence $confidence"; // Display results
        });

        // Show a popup if confidence is below 30
        if (confidence < 30) {
          _showPopupMessage('Unfamiliar Face Detected');
        }
      } else {
        setState(() {
          _apiResponse = "Error processing video: ${response.statusCode}";
        });
      }
    } catch (e) {
      setState(() {
        _apiResponse = "Error: $e";
      });
    }
  }

  void _playPauseVideo() {
    setState(() {
      if (_isVideoPlaying) {
        _videoController?.pause();
      } else {
        _videoController?.play();
      }
      _isVideoPlaying = !_isVideoPlaying;
    });
  }

  void _showPopupMessage(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Detection Result"),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text("OK"),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Video Detection'),
        actions: [
          // Button to pick a video
          IconButton(
            icon: Icon(Icons.video_library),
            onPressed: _pickVideoFromGallery,
          ),
        ],
      ),
      body: Column(
        children: [
          // Real-time Camera Preview horizontally centered with increased height
          Container(
            alignment: Alignment.center,
            margin: EdgeInsets.symmetric(vertical: 20),
            child: _isCameraInitialized
                ? Container(
                    height: 200, // Increased height
                    width: 160,
                    child: CameraPreview(_controller!),
                  )
                : CircularProgressIndicator(),
          ),

          // "Select Video" box which changes to the video preview when a video is selected
          GestureDetector(
            onTap: _pickVideoFromGallery,
            child: Container(
              width: double.infinity,
              height: 300, // Increased height by 100 pixels
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blue, width: 2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: _selectedVideo == null
                  ? Center(
                      child: Text(
                        "Select Video",
                        style: TextStyle(fontSize: 18, color: Colors.black),
                      ),
                    )
                  : _videoController!.value.isInitialized
                      ? Column(
                          children: [
                            AspectRatio(
                              aspectRatio: _videoController!.value.aspectRatio,
                              child: VideoPlayer(_videoController!),
                            ),
                            IconButton(
                              icon: Icon(_isVideoPlaying
                                  ? Icons.pause
                                  : Icons.play_arrow),
                              onPressed: _playPauseVideo,
                            ),
                          ],
                        )
                      : Center(child: CircularProgressIndicator()),
            ),
          ),
          SizedBox(height: 20),

          // Display the result from the API
          Text(
            _apiResponse,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.black),
          ),
        ],
      ),
    );
  }
}
