import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'models.dart';
import 'model/model_service.dart';

typedef void Callback(List<dynamic> list, int h, int w);

class Camera extends StatefulWidget {
  final List<CameraDescription> cameras;
  final Callback setRecognitions;
  final String model;
  final tfl.Interpreter interpreter;

  Camera(this.cameras, this.model, this.setRecognitions, this.interpreter);

  @override
  _CameraState createState() => new _CameraState();
}

class _CameraState extends State<Camera> {
  late CameraController controller;
  bool isDetecting = false;
  CameraDescription? bestCamera;
  late ModelService _modelService;
  int frameSkipCounter = 0;
  static const int framesToSkip = 3; // Process every 3rd frame to reduce lag

  @override
  void initState() {
    super.initState();
    _findBestCamera();
  }

  void _findBestCamera() {
    if (widget.cameras.isEmpty) {
      print('No camera is found');
      return;
    }

    // Try to find the back camera with the highest resolution
    bestCamera = widget.cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => widget.cameras.first,
    );

    if (bestCamera != null) {
      _initCamera();
    }
  }

  void _initCamera() {
    // Use high resolution but not max to improve performance
    controller = new CameraController(
      bestCamera!,
      ResolutionPreset.high, // Changed from max to high for better performance
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    controller.initialize().then((_) {
      if (!mounted) return;
      
      setState(() {});
      
      // Create model service with the provided interpreter
      _modelService = ModelService(model: widget.model);
      _modelService.interpreter = widget.interpreter;
      
      // Don't set zoom to avoid over-zooming
      // controller.getMinZoomLevel().then((minZoom) {
      //   controller.getMaxZoomLevel().then((maxZoom) {
      //     controller.setZoomLevel(minZoom); // Use minimum zoom instead of average
      //   });
      // });
      
      // Start image stream with optimized settings
      controller.startImageStream((CameraImage img) {
        if (!isDetecting) {
          // Skip frames to improve performance
          frameSkipCounter++;
          if (frameSkipCounter % framesToSkip != 0) {
            return;
          }
          
          isDetecting = true;
          
          int startTime = DateTime.now().millisecondsSinceEpoch;
          
          if (widget.model == mobilenet) {
            _runMobilenetModel(img).then((recognitions) {
              int endTime = DateTime.now().millisecondsSinceEpoch;
              print("Mobilenet detection took ${endTime - startTime}ms");
              
              widget.setRecognitions(recognitions, img.height, img.width);
              isDetecting = false;
            });
          } else if (widget.model == posenet) {
            _runPosenetModel(img).then((recognitions) {
              int endTime = DateTime.now().millisecondsSinceEpoch;
              print("Posenet detection took ${endTime - startTime}ms");
              
              widget.setRecognitions(recognitions, img.height, img.width);
              isDetecting = false;
            });
          } else {
            _runObjectDetectionModel(img).then((recognitions) {
              int endTime = DateTime.now().millisecondsSinceEpoch;
              print("Object detection took ${endTime - startTime}ms");
              
              widget.setRecognitions(recognitions, img.height, img.width);
              isDetecting = false;
            });
          }
        }
      });
    }).catchError((Object e) {
      if (e is CameraException) {
        switch (e.code) {
          case 'CameraAccessDenied':
            print('User denied camera access.');
            break;
          default:
            print('Handle other errors.');
            break;
        }
      }
    });
  }

  Future<List<dynamic>> _runMobilenetModel(CameraImage img) async {
    // Run inference directly using the model service
    return await _modelService.runInferenceOnCameraImage(img);
  }

  Future<List<dynamic>> _runPosenetModel(CameraImage img) async {
    // Run inference directly using the model service
    return await _modelService.runInferenceOnCameraImage(img);
  }

  Future<List<dynamic>> _runObjectDetectionModel(CameraImage img) async {
    // Run inference directly using the model service
    return await _modelService.runInferenceOnCameraImage(img);
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (controller == null || !controller.value.isInitialized) {
      return Container(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    }

    var tmp = MediaQuery.of(context).size;
    var screenH = math.max(tmp.height, tmp.width);
    var screenW = math.min(tmp.height, tmp.width);
    
    // Fixed nullable previewSize issue
    final previewSize = controller.value.previewSize;
    if (previewSize == null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Text('Camera preview not available'),
        ),
      );
    }
    
    var previewH = math.max(previewSize.height, previewSize.width);
    var previewW = math.min(previewSize.height, previewSize.width);
    var screenRatio = screenH / screenW;
    var previewRatio = previewH / previewW;

    return Container(
      color: Colors.black,
      child: OverflowBox(
        maxHeight:
            screenRatio > previewRatio ? screenH : screenW / previewW * previewH,
        maxWidth:
            screenRatio > previewRatio ? screenH / previewH * previewW : screenW,
        child: CameraPreview(controller),
      ),
    );
  }
}