import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'package:camera/camera.dart';
import 'model_labels.dart';
import 'imagenet_labels.dart';

class ModelService {
  final String model;
  tfl.Interpreter? _interpreter;
  
  tfl.Interpreter? get interpreter => _interpreter;
  
  set interpreter(tfl.Interpreter? interpreter) {
    _interpreter = interpreter;
  }

  ModelService({required this.model});

  Future<void> loadModel() async {
    try {
      tfl.Interpreter? interpreter;
      switch (model) {
        case 'yolo':
          interpreter = await tfl.Interpreter.fromAsset("assets/yolov2_tiny.tflite");
          break;
        case 'mobilenet':
          interpreter = await tfl.Interpreter.fromAsset("assets/mobilenet_v1_1.0_224.tflite");
          break;
        case 'mobilenet_v2':
          interpreter = await tfl.Interpreter.fromAsset("assets/MobileNet-v2.tflite");
          break;
        case 'mobilenet_v3_large':
          interpreter = await tfl.Interpreter.fromAsset("assets/MobileNet-v3-Large.tflite");
          break;
        case 'mobilenet_v3_large_float':
          interpreter = await tfl.Interpreter.fromAsset("assets/mobilenet_v3_large-mobilenet-v3-large-float.tflite");
          break;
        case 'posenet':
          interpreter = await tfl.Interpreter.fromAsset("assets/posenet_mv1_075_float_from_checkpoints.tflite");
          break;
        case 'yolov5s':
          interpreter = await tfl.Interpreter.fromAsset("assets/yolov5s_f16.tflite");
          break;
        case 'yolov5sdynm':
          interpreter = await tfl.Interpreter.fromAsset("assets/yolov5sdynm_range.tflite");
          break;
        default:
          interpreter = await tfl.Interpreter.fromAsset("assets/ssd_mobilenet.tflite");
      }
      
      // Get input and output tensors
      final inputTensor = interpreter.getInputTensor(0);
      final outputTensor = interpreter.getOutputTensor(0);
      
      print("Model loaded: $model");
      print("Input shape: ${inputTensor.shape}");
      print("Output type: ${inputTensor.type}");
      print("Output shape: ${outputTensor.shape}");
      print("Output type: ${outputTensor.type}");
      
      _interpreter = interpreter;
    } catch (e) {
      print("Error loading model: $e");
      rethrow;
    }
  }

  Future<List<dynamic>> runInference(ui.Image image) async {
    if (_interpreter == null) return [];

    try {
      // Get input and output tensors
      final inputTensor = _interpreter!.getInputTensor(0);
      final outputTensor = _interpreter!.getOutputTensor(0);
      final inputShape = inputTensor.shape;
      final outputShape = outputTensor.shape;
      final inputType = inputTensor.type;
      final outputType = outputTensor.type;
      
      print("Processing with model: $model");
      print("Input shape: $inputShape");
      print("Output shape: $outputShape");
      print("Input type: $inputType");
      print("Output type: $outputType");
      
      // Resize image to model input size
      final inputSize = inputShape[1]; // Height
      final resizedImage = await resizeImage(image, inputSize);
      
      // Prepare input based on tensor type and shape
      dynamic input;
      if (inputType.toString().contains('uint8')) {
        // Create a 4D tensor [1, height, width, 3]
        input = List.generate(1, (i) => 
          List.generate(inputSize, (j) => 
            List.generate(inputSize, (k) => 
              List<int>.filled(3, 0)
            )
          )
        );
        
        // Fill the tensor with image data
        final byteData = await resizedImage.toByteData(format: ui.ImageByteFormat.rawRgba);
        final buffer = byteData!.buffer.asUint8List();
        
        int bufferIndex = 0;
        for (int j = 0; j < inputSize; j++) {
          for (int k = 0; k < inputSize; k++) {
            input[0][j][k][0] = buffer[bufferIndex++]; // R
            input[0][j][k][1] = buffer[bufferIndex++]; // G
            input[0][j][k][2] = buffer[bufferIndex++]; // B
            bufferIndex++; // Skip alpha channel
          }
        }
      } else {
        // Create a 4D tensor [1, height, width, 3]
        input = List.generate(1, (i) => 
          List.generate(inputSize, (j) => 
            List.generate(inputSize, (k) => 
              List<double>.filled(3, 0.0)
            )
          )
        );
        
        // Fill the tensor with normalized image data
        final byteData = await resizedImage.toByteData(format: ui.ImageByteFormat.rawRgba);
        final buffer = byteData!.buffer.asUint8List();
        
        int bufferIndex = 0;
        for (int j = 0; j < inputSize; j++) {
          for (int k = 0; k < inputSize; k++) {
            input[0][j][k][0] = buffer[bufferIndex++] / 255.0; // R
            input[0][j][k][1] = buffer[bufferIndex++] / 255.0; // G
            input[0][j][k][2] = buffer[bufferIndex++] / 255.0; // B
            bufferIndex++; // Skip alpha channel
          }
        }
      }
      
      // Prepare output buffer based on model's output shape and type
      dynamic output;
      if (outputType.toString().contains('uint8')) {
        // Create output tensor with the correct shape
        output = _createOutputTensor<int>(outputShape, 0);
      } else {
        // Create output tensor with the correct shape
        output = _createOutputTensor<double>(outputShape, 0.0);
      }
      
      // Run inference
      _interpreter!.run(input, output);
      
      // Process results
      final recognitions = _processResults(output, outputShape, outputType.toString());
      
      return recognitions;
    } catch (e) {
      print("Error running inference for $model: $e");
      return [];
    }
  }

  // New method for camera image processing
  Future<List<dynamic>> runInferenceOnCameraImage(CameraImage image) async {
    if (_interpreter == null) return [];

    try {
      // Get input and output tensors
      final inputTensor = _interpreter!.getInputTensor(0);
      final outputTensor = _interpreter!.getOutputTensor(0);
      final inputShape = inputTensor.shape;
      final outputShape = outputTensor.shape;
      final inputType = inputTensor.type;
      final outputType = outputTensor.type;
      
      // Resize image to model input size
      final inputSize = inputShape[1]; // Height
      
      // Prepare input based on tensor type and shape
      dynamic input;
      if (inputType.toString().contains('uint8')) {
        // Create a 4D tensor [1, height, width, 3]
        input = List.generate(1, (i) => 
          List.generate(inputSize, (j) => 
            List.generate(inputSize, (k) => 
              List<int>.filled(3, 0)
            )
          )
        );
        
        // Convert and resize camera image to tensor
        _convertCameraImageToTensor(image, input, inputSize);
      } else {
        // Create a 4D tensor [1, height, width, 3]
        input = List.generate(1, (i) => 
          List.generate(inputSize, (j) => 
            List.generate(inputSize, (k) => 
              List<double>.filled(3, 0.0)
            )
          )
        );
        
        // Convert and resize camera image to tensor with normalization
        _convertCameraImageToTensorNormalized(image, input, inputSize);
      }
      
      // Prepare output buffer based on model's output shape and type
      dynamic output;
      if (outputType.toString().contains('uint8')) {
        // Create output tensor with the correct shape
        output = _createOutputTensor<int>(outputShape, 0);
      } else {
        // Create output tensor with the correct shape
        output = _createOutputTensor<double>(outputShape, 0.0);
      }
      
      // Run inference
      _interpreter!.run(input, output);
      
      // Process results
      final recognitions = _processResults(output, outputShape, outputType.toString());
      
      return recognitions;
    } catch (e) {
      print("Error running camera inference for $model: $e");
      return [];
    }
  }

  // Helper method to convert camera image to tensor (uint8)
  void _convertCameraImageToTensor(CameraImage image, dynamic input, int inputSize) {
    // Convert YUV420 to RGB
    final int width = image.width;
    final int height = image.height;
    final int uvRowStride = image.planes[1].bytesPerRow;
    final int uvPixelStride = image.planes[1].bytesPerPixel!;
    
    // Calculate scaling factors
    final scaleX = width / inputSize;
    final scaleY = height / inputSize;
    
    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        // Calculate corresponding position in original image
        final int origY = (y * scaleY).toInt();
        final int origX = (x * scaleX).toInt();
        
        final int uvIndex = uvPixelStride * (origX ~/ 2) + uvRowStride * (origY ~/ 2);
        
        // Get YUV values
        final int yValue = image.planes[0].bytes[origY * image.planes[0].bytesPerRow + origX];
        final int uValue = image.planes[1].bytes[uvIndex];
        final int vValue = image.planes[2].bytes[uvIndex];
        
        // Convert YUV to RGB
        input[0][y][x][0] = (yValue + 1.402 * (vValue - 128)).clamp(0, 255).toInt(); // R
        input[0][y][x][1] = (yValue - 0.34414 * (uValue - 128) - 0.71414 * (vValue - 128)).clamp(0, 255).toInt(); // G
        input[0][y][x][2] = (yValue + 1.772 * (uValue - 128)).clamp(0, 255).toInt(); // B
      }
    }
  }

  // Helper method to convert camera image to tensor with normalization (float)
  void _convertCameraImageToTensorNormalized(CameraImage image, dynamic input, int inputSize) {
    // Convert YUV420 to RGB
    final int width = image.width;
    final int height = image.height;
    final int uvRowStride = image.planes[1].bytesPerRow;
    final int uvPixelStride = image.planes[1].bytesPerPixel!;
    
    // Calculate scaling factors
    final scaleX = width / inputSize;
    final scaleY = height / inputSize;
    
    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        // Calculate corresponding position in original image
        final int origY = (y * scaleY).toInt();
        final int origX = (x * scaleX).toInt();
        
        final int uvIndex = uvPixelStride * (origX ~/ 2) + uvRowStride * (origY ~/ 2);
        
        // Get YUV values
        final int yValue = image.planes[0].bytes[origY * image.planes[0].bytesPerRow + origX];
        final int uValue = image.planes[1].bytes[uvIndex];
        final int vValue = image.planes[2].bytes[uvIndex];
        
        // Convert YUV to RGB and normalize to [0,1]
        input[0][y][x][0] = (yValue + 1.402 * (vValue - 128)).clamp(0, 255).toDouble() / 255.0; // R
        input[0][y][x][1] = (yValue - 0.34414 * (uValue - 128) - 0.71414 * (vValue - 128)).clamp(0, 255).toDouble() / 255.0; // G
        input[0][y][x][2] = (yValue + 1.772 * (uValue - 128)).clamp(0, 255).toDouble() / 255.0; // B
      }
    }
  }

  // Helper function to create output tensor with the correct shape
  dynamic _createOutputTensor<T>(List<int> shape, T defaultValue) {
    if (shape.length == 1) {
      return List<T>.filled(shape[0], defaultValue);
    } else if (shape.length == 2) {
      return List<List<T>>.generate(
        shape[0],
        (i) => List<T>.filled(shape[1], defaultValue)
      );
    } else if (shape.length == 3) {
      return List<List<List<T>>>.generate(
        shape[0],
        (i) => List<List<T>>.generate(
          shape[1],
          (j) => List<T>.filled(shape[2], defaultValue)
        )
      );
    } else if (shape.length == 4) {
      return List<List<List<List<T>>>>.generate(
        shape[0],
        (i) => List<List<List<T>>>.generate(
          shape[1],
          (j) => List<List<T>>.generate(
            shape[2],
            (k) => List<T>.filled(shape[3], defaultValue)
          )
        )
      );
    } else {
      throw Exception("Unsupported tensor shape: $shape");
    }
  }

  Future<ui.Image> resizeImage(ui.Image image, int size) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = ui.Canvas(pictureRecorder);
    final paint = ui.Paint();
    
    canvas.drawImageRect(
      image,
      ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
      paint,
    );
    
    final picture = pictureRecorder.endRecording();
    return await picture.toImage(size, size);
  }

  List<dynamic> _processResults(dynamic output, List<int> outputShape, String outputType) {
    List<dynamic> results = <dynamic>[];
    final labels = labelMaps[model] ?? [];
    
    switch (model) {
      case 'ssd':
        // SSD MobileNet output processing
        if (output == null) return results;
        
        List<List<double>> detections = [];
        for (int i = 0; i < outputShape[1]; i++) {
          List<double> detection = [];
          for (int j = 0; j < outputShape[2]; j++) {
            if (outputType.contains('uint8')) {
              detection.add(output[0][i][j].toDouble());
            } else {
              detection.add(output[0][i][j]);
            }
          }
          detections.add(detection);
        }
        
        const double threshold = 0.3;
        
        for (int i = 0; i < detections.length; i++) {
          final detection = detections[i];
          final double score = detection[0];
          
          if (score > threshold) {
            final double ymin = detection[1];
            final double xmin = detection[2];
            final double ymax = detection[3];
            final double xmax = detection[4];
            
            final double width = xmax - xmin;
            final double height = ymax - ymin;
            
            final int classIndex = detection[0].round().toInt();
            final String label = classIndex < labels.length && classIndex > 0 
                ? labels[classIndex] 
                : "Unknown";
            
            // Return result without bounding box for display
            results.add({
              "label": label,
              "confidence": score,
              "type": "detection",
            });
          }
        }
        break;
        
      case 'yolo':
        // YOLO output processing
        if (output == null) return results;
        
        List<List<List<double>>> grid = [];
        for (int i = 0; i < outputShape[1]; i++) {
          List<List<double>> row = [];
          for (int j = 0; j < outputShape[2]; j++) {
            List<double> cell = [];
            for (int k = 0; k < outputShape[3]; k++) {
              if (outputType.contains('uint8')) {
                cell.add(output[0][i][j][k].toDouble());
              } else {
                cell.add(output[0][i][j][k]);
              }
            }
            row.add(cell);
          }
          grid.add(row);
        }
        
        final int gridSize = 13;
        final int numBoxes = 5;
        final int numClasses = 80;
        final int boxSize = 5 + numClasses;
        
        const double threshold = 0.3;
        
        // Store all potential detections first
        List<Map<String, dynamic>> potentialDetections = [];
        
        for (int gridY = 0; gridY < gridSize; gridY++) {
          for (int gridX = 0; gridX < gridSize; gridX++) {
            for (int box = 0; box < numBoxes; box++) {
              final int offset = box * boxSize;
              
              final double objectness = _sigmoid(grid[gridY][gridX][offset + 4]);
              
              if (objectness > threshold) {
                int maxClassIndex = 0;
                double maxClassProb = 0;
                
                for (int i = 5; i < boxSize; i++) {
                  final double classProb = _sigmoid(grid[gridY][gridX][offset + i]) * objectness;
                  if (classProb > maxClassProb) {
                    maxClassProb = classProb;
                    maxClassIndex = i - 5;
                  }
                }
                
                if (maxClassProb > threshold) {
                  final double tx = grid[gridY][gridX][offset];
                  final double ty = grid[gridY][gridX][offset + 1];
                  final double tw = grid[gridY][gridX][offset + 2];
                  final double th = grid[gridY][gridX][offset + 3];
                  
                  final double bx = (gridX + _sigmoid(tx)) / gridSize;
                  final double by = (gridY + _sigmoid(ty)) / gridSize;
                  final double bw = math.exp(tw) * 0.422373 / gridSize;
                  final double bh = math.exp(th) * 0.503555 / gridSize;
                  
                  final double xmin = bx - bw / 2;
                  final double ymin = by - bh / 2;
                  final double xmax = bx + bw / 2;
                  final double ymax = by + bh / 2;
                  
                  final String label = maxClassIndex < labels.length 
                      ? labels[maxClassIndex] 
                      : "Unknown";
                  
                  if (_isCommonObject(label)) {
                    // Store potential detection with its coordinates
                    potentialDetections.add({
                      "label": label,
                      "confidence": maxClassProb,
                      "x": xmin,
                      "y": ymin,
                      "width": xmax - xmin,
                      "height": ymax - ymin,
                      "originalBox": [xmin, ymin, xmax, ymax]
                    });
                  }
                }
              }
            }
          }
        }
        
        // Apply Non-Maximum Suppression to filter overlapping detections
        results = _applyNMS(potentialDetections, 0.45);
        break;
        
      case 'yolov5s':
      case 'yolov5sdynm':
        // YOLOv5 output processing
        if (output == null) return results;
        
        List<List<double>> detections = [];
        for (int i = 0; i < outputShape[1]; i++) {
          List<double> detection = [];
          for (int j = 0; j < outputShape[2]; j++) {
            if (outputType.contains('uint8')) {
              detection.add(output[0][i][j].toDouble());
            } else {
              detection.add(output[0][i][j]);
            }
          }
          detections.add(detection);
        }
        
        const double threshold = 0.25;
        const double nmsThreshold = 0.45;
        
        // Store all potential detections first
        List<Map<String, dynamic>> potentialDetections = [];
        
        for (int i = 0; i < detections.length; i++) {
          final detection = detections[i];
          
          double maxClassScore = 0;
          int maxClassIndex = 0;
          
          for (int j = 5; j < detection.length; j++) {
            if (detection[j] > maxClassScore) {
              maxClassScore = detection[j];
              maxClassIndex = j - 5;
            }
          }
          
          final double confidence = detection[4] * maxClassScore;
          
          if (confidence > threshold) {
            final double centerX = detection[0];
            final double centerY = detection[1];
            final double width = detection[2];
            final double height = detection[3];
            
            final double xmin = centerX - width / 2;
            final double ymin = centerY - height / 2;
            final double xmax = centerX + width / 2;
            final double ymax = centerY + height / 2;
            
            final String label = maxClassIndex < labels.length 
                ? labels[maxClassIndex] 
                : "Unknown";
            
            if (_isCommonObject(label)) {
              // Store potential detection with its coordinates
              potentialDetections.add({
                "label": label,
                "confidence": confidence,
                "x": xmin,
                "y": ymin,
                "width": xmax - xmin,
                "height": ymax - ymin,
                "originalBox": [xmin, ymin, xmax, ymax]
              });
            }
          }
        }
        
        // Apply Non-Maximum Suppression to filter overlapping detections
        results = _applyNMS(potentialDetections, nmsThreshold);
        break;
        
      case 'mobilenet':
      case 'mobilenet_v2':
      case 'mobilenet_v3_large':
      case 'mobilenet_v3_large_float':
        // MobileNet classification output processing
        if (output == null) return results;
        
        List<double> classProbabilities = [];
        int numClasses = outputShape[1];
        
        for (int i = 0; i < numClasses; i++) {
          if (outputType.contains('uint8')) {
            classProbabilities.add(output[0][i].toDouble());
          } else {
            classProbabilities.add(output[0][i]);
          }
        }
        
        // Normalize probabilities using softmax
        final double maxLogit = classProbabilities.reduce((a, b) => a > b ? a : b);
        final List<double> expLogits = classProbabilities.map((logit) => math.exp(logit - maxLogit)).toList();
        final double sumExp = expLogits.reduce((a, b) => a + b);
        
        // Convert to probabilities
        final List<double> probabilities = expLogits.map((expLogit) => expLogit / sumExp).toList();
        
        // Create a list of (index, probability) pairs
        List<Map<String, dynamic>> indexedProbs = [];
        for (int i = 0; i < probabilities.length; i++) {
          // Get label from ImageNet labels
          String label;
          if (i < imagenetLabels.length) {
            label = imagenetLabels[i];
          } else {
            label = "Class $i";
          }
          
          indexedProbs.add({
            'index': i,
            'probability': probabilities[i],
            'label': label
          });
        }
        
        // Sort by probability in descending order
        indexedProbs.sort((a, b) => b['probability'].compareTo(a['probability']));
        
        // Get top 5 predictions
        const int topK = 5;
        const double threshold = 0.01; // Very low threshold
        
        // Always add at least the top prediction
        if (indexedProbs.isNotEmpty) {
          final topPrediction = indexedProbs[0];
          final String label = topPrediction['label'];
          final double confidence = topPrediction['probability'] * 100; // Convert to percentage
          
          results.add({
            "label": label,
            "confidence": confidence,
            "type": "classification",
          });
          
          // Add other top predictions if they meet threshold
          for (int i = 1; i < math.min(topK, indexedProbs.length); i++) {
            final prediction = indexedProbs[i];
            final double confidence = prediction['probability'] * 100; // Convert to percentage
            final String label = prediction['label'];
            
            if (confidence > threshold) {
              results.add({
                "label": label,
                "confidence": confidence,
                "type": "classification",
              });
            }
          }
        }
        break;
        
      case 'posenet':
        // PoseNet output processing
        if (output == null) return results;
        
        List<List<List<double>>> heatmap = [];
        for (int i = 0; i < outputShape[1]; i++) {
          List<List<double>> row = [];
          for (int j = 0; j < outputShape[2]; j++) {
            List<double> cell = [];
            for (int k = 0; k < outputShape[3]; k++) {
              if (outputType.contains('uint8')) {
                cell.add(output[0][i][j][k].toDouble());
              } else {
                cell.add(output[0][i][j][k]);
              }
            }
            row.add(cell);
          }
          heatmap.add(row);
        }
        
        final int gridSize = 22; // Updated for PoseNet
        final int numKeypoints = 17;
        
        const double threshold = 0.3;
        
        for (int k = 0; k < numKeypoints; k++) {
          double maxConfidence = 0;
          int maxX = 0;
          int maxY = 0;
          
          // Find the position with maximum confidence for this keypoint
          for (int y = 0; y < gridSize; y++) {
            for (int x = 0; x < gridSize; x++) {
              final double confidence = _sigmoid(heatmap[y][x][k]);
              
              if (confidence > maxConfidence) {
                maxConfidence = confidence;
                maxX = x;
                maxY = y;
              }
            }
          }
          
          if (maxConfidence > threshold) {
            // Normalize coordinates to [0,1]
            final double x = maxX / gridSize;
            final double y = maxY / gridSize;
            
            // Get label name
            final String label = k < labels.length 
                ? labels[k] 
                : "Keypoint $k";
            
            results.add({
              "label": label,
              "confidence": maxConfidence,
              "type": "keypoint",
              "position": {"x": x, "y": y}
            });
          }
        }
        break;
      
      default:
        // Handle default case (SSD MobileNet)
        if (output == null) return results;
        
        // Try to process as SSD format
        try {
          List<List<double>> detections = [];
          for (int i = 0; i < outputShape[1]; i++) {
            List<double> detection = [];
            for (int j = 0; j < outputShape[2]; j++) {
              if (outputType.contains('uint8')) {
                detection.add(output[0][i][j].toDouble());
              } else {
                detection.add(output[0][i][j]);
              }
            }
            detections.add(detection);
          }
          
          const double threshold = 0.3;
          
          for (int i = 0; i < detections.length; i++) {
            final detection = detections[i];
            final double score = detection[0];
            
            if (score > threshold) {
              final double ymin = detection[1];
              final double xmin = detection[2];
              final double ymax = detection[3];
              final double xmax = detection[4];
              
              final double width = xmax - xmin;
              final double height = ymax - ymin;
              
              final int classIndex = detection[0].round().toInt();
              // Use SSD labels as fallback
              final labelsForDefault = labelMaps['ssd'] ?? [];
              final String label = classIndex < labelsForDefault.length && classIndex > 0 
                  ? labelsForDefault[classIndex] 
                  : "Unknown";
              
              // Return result without bounding box for display
              results.add({
                "label": label,
                "confidence": score,
                "type": "detection",
              });
            }
          }
        } catch (e) {
          print("Error processing default model output: $e");
          return [];
        }
        break;
    }
    
    return results;
  }

  // Apply Non-Maximum Suppression to filter overlapping detections
  List<dynamic> _applyNMS(List<dynamic> detections, double nmsThreshold) {
    // Sort detections by confidence in descending order
    detections.sort((a, b) => (b['confidence'] as double).compareTo(a['confidence'] as double));
    
    List<dynamic> finalDetections = [];
    
    while (detections.isNotEmpty) {
      // Add the detection with highest confidence
      finalDetections.add(detections.first);
      
      // Remove overlapping detections
      detections = detections.where((detection) {
        // Calculate IoU with the current detection
        final double iou = _calculateIoU(finalDetections.last, detection);
        return iou < nmsThreshold;
      }).toList();
    }
    
    // Convert to format without bounding boxes for display
    return finalDetections.map((detection) {
      return {
        "label": detection["label"],
        "confidence": detection["confidence"],
        "type": "detection",
      };
    }).toList();
  }

  // Calculate Intersection over Union (IoU) of two bounding boxes
  double _calculateIoU(dynamic box1, dynamic box2) {
    // Extract coordinates
    final double x1_min = box1['x'];
    final double y1_min = box1['y'];
    final double x1_max = x1_min + box1['width'];
    final double y1_max = y1_min + box1['height'];
    
    final double x2_min = box2['x'];
    final double y2_min = box2['y'];
    final double x2_max = x2_min + box2['width'];
    final double y2_max = y2_min + box2['height'];
    
    // Calculate intersection area
    final double inter_x_min = math.max(x1_min, x2_min);
    final double inter_y_min = math.max(y1_min, y2_min);
    final double inter_x_max = math.min(x1_max, x2_max);
    final double inter_y_max = math.min(y1_max, y2_max);
    
    final double inter_width = math.max(0.0, inter_x_max - inter_x_min);
    final double inter_height = math.max(0.0, inter_y_max - inter_y_min);
    final double inter_area = inter_width * inter_height;
    
    // Calculate union area
    final double box1_area = box1['width'] * box1['height'];
    final double box2_area = box2['width'] * box2['height'];
    final double union_area = box1_area + box2_area - inter_area;
    
    // Calculate IoU
    if (union_area == 0) return 0.0;
    return inter_area / union_area;
  }

  double _sigmoid(double x) {
    if (x < -10.0) return 0.0;
    if (x > 10.0) return 1.0;
    return 1 / (1 + math.exp(-x));
  }

  bool _isCommonObject(String label) {
    if (label.isEmpty || label.toLowerCase() == "background") return false;
    
    // List of common objects we want to detect
    const commonObjects = {
      'person', 'bicycle', 'car', 'motorcycle', 'airplane', 'bus', 'train', 'truck',
      'boat', 'traffic light', 'fire hydrant', 'stop sign', 'parking meter', 'bench',
      'bird', 'cat', 'dog', 'horse', 'sheep', 'cow', 'elephant', 'bear', 'zebra',
      'giraffe', 'backpack', 'umbrella', 'handbag', 'tie', 'suitcase', 'frisbee',
      'skis', 'snowboard', 'sports ball', 'kite', 'baseball bat', 'baseball glove',
      'skateboard', 'surfboard', 'tennis racket', 'bottle', 'wine glass', 'cup',
      'fork', 'knife', 'spoon', 'bowl', 'banana', 'apple', 'sandwich', 'orange',
      'broccoli', 'carrot', 'hot dog', 'pizza', 'donut', 'cake', 'chair', 'couch',
      'potted plant', 'bed', 'dining table', 'toilet', 'tv', 'laptop', 'mouse',
      'remote', 'keyboard', 'cell phone', 'microwave', 'oven', 'toaster', 'sink',
      'refrigerator', 'book', 'clock', 'vase', 'scissors', 'teddy bear', 'hair drier',
      'toothbrush'
    };
    
    return commonObjects.contains(label.toLowerCase().trim());
  }

  void dispose() {
    _interpreter?.close();
  }
}