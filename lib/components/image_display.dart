import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';

class ImageDisplayComponent extends StatefulWidget {
  final File? selectedImage;
  final Uint8List? imageBytes;
  final Map<String, List<dynamic>> modelResults;
  final VoidCallback onRemoveImage;
  final VoidCallback onAddAnotherImage;
  
  ImageDisplayComponent({
    required this.selectedImage,
    required this.imageBytes,
    required this.modelResults,
    required this.onRemoveImage,
    required this.onAddAnotherImage,
  });

  @override
  _ImageDisplayComponentState createState() => _ImageDisplayComponentState();
}

class _ImageDisplayComponentState extends State<ImageDisplayComponent> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _showControls = true;
  ui.Image? _annotatedImage;

  @override
  void initState() {
    super.initState();
    _generateAnnotatedImage();
  }

  @override
  void didUpdateWidget(ImageDisplayComponent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.modelResults != widget.modelResults) {
      _generateAnnotatedImage();
    }
  }

  Future<void> _generateAnnotatedImage() async {
    if (widget.selectedImage == null || widget.imageBytes == null || widget.modelResults.isEmpty) {
      return;
    }

    try {
      final originalImage = await decodeImageFromList(widget.imageBytes!);
      final pictureRecorder = ui.PictureRecorder();
      final canvas = Canvas(pictureRecorder);
      final paint = Paint();
      
      // Draw the original image
      canvas.drawImageRect(
        originalImage,
        Rect.fromLTWH(0, 0, originalImage.width.toDouble(), originalImage.height.toDouble()),
        Rect.fromLTWH(0, 0, originalImage.width.toDouble(), originalImage.height.toDouble()),
        paint,
      );
      
      // Draw bounding boxes
      final boxPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0;
      
      final textPainter = TextPainter(
        textDirection: TextDirection.ltr,
      );
      
      widget.modelResults.entries.forEach((entry) {
        final model = entry.key;
        final recognitions = entry.value;
        final color = _getModelColor(model);
        
        boxPaint.color = color;
        
        for (final recognition in recognitions) {
          final x = recognition['x'] * originalImage.width;
          final y = recognition['y'] * originalImage.height;
          final width = recognition['width'] * originalImage.width;
          final height = recognition['height'] * originalImage.height;
          
          // Draw bounding box
          canvas.drawRect(
            Rect.fromLTWH(x, y, width, height),
            boxPaint,
          );
          
          // Draw label background
          final label = '${recognition['label']} ${(recognition['confidence'] * 100).toStringAsFixed(1)}%';
          textPainter.text = TextSpan(
            text: label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          );
          textPainter.layout();
          
          final labelBackground = Rect.fromLTWH(
            x,
            y - textPainter.height - 4,
            textPainter.width + 8,
            textPainter.height + 4,
          );
          
          canvas.drawRect(
            labelBackground,
            Paint()..color = color,
          );
          
          // Draw label text
          textPainter.paint(
            canvas,
            Offset(x + 4, y - textPainter.height - 2),
          );
        }
      });
      
      final picture = pictureRecorder.endRecording();
      final annotatedImage = await picture.toImage(
        originalImage.width,
        originalImage.height,
      );
      
      setState(() {
        _annotatedImage = annotatedImage;
      });
    } catch (e) {
      print('Error generating annotated image: $e');
    }
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildImageSlider(),
        SizedBox(height: 16),
        _buildImageIndicator(),
        SizedBox(height: 16),
        _buildActionButtons(),
      ],
    );
  }

  Widget _buildImageSlider() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showControls = !_showControls;
        });
      },
      child: Container(
        height: 300,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(blurRadius: 8, color: Colors.black12)],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                children: [
                  // Original Image
                  widget.imageBytes != null
                      ? Image.memory(
                          widget.imageBytes!,
                          fit: BoxFit.contain,
                        )
                      : Image.file(
                          widget.selectedImage!,
                          fit: BoxFit.contain,
                        ),
                  // Annotated Image
                  _annotatedImage != null
                      ? RawImage(
                          image: _annotatedImage,
                          fit: BoxFit.contain,
                        )
                      : Center(
                          child: CircularProgressIndicator(),
                        ),
                ],
              ),
              // Full screen button
              if (_showControls)
                Positioned(
                  top: 8,
                  right: 8,
                  child: FloatingActionButton(
                    mini: true,
                    backgroundColor: Colors.black54,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FullScreenImageViewer(
                            image: _currentPage == 0
                                ? widget.imageBytes
                                : _annotatedImage,
                            isOriginalImage: _currentPage == 0,
                            title: _currentPage == 0 ? "Original Image" : "Annotated Image",
                          ),
                        ),
                      );
                    },
                    child: Icon(Icons.fullscreen, color: Colors.white),
                  ),
                ),
              // Image label
              if (_showControls)
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _currentPage == 0 ? "Original Image" : "Annotated Image",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedContainer(
          duration: Duration(milliseconds: 300),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _currentPage == 0 ? Colors.deepPurple : Colors.grey,
          ),
        ),
        SizedBox(width: 8),
        AnimatedContainer(
          duration: Duration(milliseconds: 300),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _currentPage == 1 ? Colors.deepPurple : Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 12),
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 2,
            ),
            onPressed: widget.onRemoveImage,
            icon: Icon(Icons.delete),
            label: Text('Remove Image'),
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 12),
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 2,
            ),
            onPressed: widget.onAddAnotherImage,
            icon: Icon(Icons.add_photo_alternate),
            label: Text('Add Another'),
          ),
        ),
      ],
    );
  }
}

class FullScreenImageViewer extends StatefulWidget {
  final dynamic image;
  final bool isOriginalImage;
  final String title;

  FullScreenImageViewer({
    required this.image,
    required this.isOriginalImage,
    required this.title,
  });

  @override
  _FullScreenImageViewerState createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  double _scale = 1.0;
  double _previousScale = 1.0;
  bool _showControls = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _showControls = !_showControls;
                });
              },
              onScaleStart: (details) {
                _previousScale = _scale;
              },
              onScaleUpdate: (details) {
                setState(() {
                  _scale = _previousScale * details.scale;
                });
              },
              child: Transform.scale(
                scale: _scale,
                child: widget.isOriginalImage
                    ? Image.memory(
                        widget.image,
                        fit: BoxFit.contain,
                      )
                    : RawImage(
                        image: widget.image,
                        fit: BoxFit.contain,
                      ),
              ),
            ),
          ),
          if (_showControls)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AppBar(
                backgroundColor: Colors.black54,
                elevation: 0,
                title: Text(widget.title),
                centerTitle: true,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}