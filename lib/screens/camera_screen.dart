import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'dart:math' as math;

import '../camera.dart';
import '../bndbox.dart';
import '../model/model_service.dart';

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final String model;

  CameraScreen({required this.cameras, required this.model});

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  List<dynamic> _recognitions = []; // Initialize with empty list instead of late
  int _imageHeight = 0;
  int _imageWidth = 0;
  ModelService? _modelService;
  bool _isModelLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  Future<void> _loadModel() async {
    _modelService = ModelService(model: widget.model);
    await _modelService!.loadModel();
    setState(() {
      _isModelLoaded = true;
    });
  }

  void setRecognitions(List<dynamic> recognitions, int imageHeight, int imageWidth) {
    setState(() {
      // Ensure recognitions is not null
      _recognitions = recognitions ?? [];
      _imageHeight = imageHeight;
      _imageWidth = imageWidth;
    });
  }

  @override
  void dispose() {
    _modelService?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Size screen = MediaQuery.of(context).size;
    return Scaffold(
      appBar: AppBar(
        title: Text('Live Detection - ${widget.model}'),
        backgroundColor: Colors.deepPurple,
        elevation: 0,
      ),
      body: _isModelLoaded
          ? Stack(
              children: [
                Camera(
                  widget.cameras,
                  widget.model,
                  setRecognitions,
                  _modelService!.interpreter!,
                ),
                // Add null check for recognitions
                if (_recognitions.isNotEmpty)
                  BndBox(
                    _recognitions,
                    math.max(_imageHeight, _imageWidth),
                    math.min(_imageHeight, _imageWidth),
                    screen.height,
                    screen.width,
                    widget.model,
                  ),
              ],
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Loading ${widget.model} model...',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
    );
  }
}