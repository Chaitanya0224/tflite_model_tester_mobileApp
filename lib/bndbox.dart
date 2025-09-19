import 'package:flutter/material.dart';
import 'dart:math' as math;

class BndBox extends StatelessWidget {
  final List<dynamic> results;
  final int previewH;
  final int previewW;
  final double screenH;
  final double screenW;
  final String model;

  BndBox(this.results, this.previewH, this.previewW, this.screenH, this.screenW, this.model);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: _renderBoxes(),
    );
  }

  List<Widget> _renderBoxes() {
    // Check if results is null or empty
    if (results.isEmpty) {
      return [];
    }

    return results.map((re) {
      // Check if recognition is null
      if (re == null) {
        return Container();
      }

      // Check if required fields are present
      if (re["x"] == null || re["y"] == null || re["width"] == null || re["height"] == null) {
        return Container();
      }

      // Get bounding box coordinates
      double x = re["x"] * screenW;
      double y = re["y"] * screenH;
      double w = re["width"] * screenW;
      double h = re["height"] * screenH;

      // Get label and confidence
      String label = re["label"] ?? "Unknown";
      double confidence = re["confidence"] ?? 0.0;

      // Get color based on model
      Color color = _getModelColor(model);

      return Positioned(
        left: math.max(0, x),
        top: math.max(0, y),
        width: math.min(w, screenW),
        height: math.min(h, screenH),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: color,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                color: color,
                child: Text(
                  '$label ${(confidence * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  Color _getModelColor(String model) {
    switch (model) {
      case 'ssd':
        return Colors.blue;
      case 'yolo':
        return Colors.green;
      case 'mobilenet':
        return Colors.orange;
      case 'posenet':
        return Colors.purple;
      default:
        return Colors.deepPurple;
    }
  }
}