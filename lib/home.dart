import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:image_picker/image_picker.dart';

import 'camera.dart';
import 'bndbox.dart';
import 'models.dart';
import 'model/model_service.dart';
import 'components/image_display.dart';
import 'screens/camera_screen.dart';

class HomePage extends StatefulWidget {
  final List<CameraDescription> cameras;

  HomePage(this.cameras);

  @override
  _HomePageState createState() => new _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<dynamic>? _recognitions;
  int _imageHeight = 0;
  int _imageWidth = 0;
  String _model = "";
  
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  List<String> _selectedModels = [];
  Map<String, List<dynamic>> _modelResults = {};
  bool _isAnalyzing = false;
  Uint8List? _imageBytes;
  ui.Image? _originalImage;
  
  Map<String, ModelService> _modelServices = {};
  Map<String, String> _modelErrors = {};

  @override
  void initState() {
    super.initState();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final bytes = await image.readAsBytes();
      final decodedImage = await decodeImageFromList(bytes);
      
      setState(() {
        _selectedImage = File(image.path);
        _imageBytes = bytes;
        _originalImage = decodedImage;
        _selectedModels = [];
        _modelResults = {};
        _modelErrors = {};
        _modelServices = {};
      });
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
      _imageBytes = null;
      _originalImage = null;
      _selectedModels = [];
      _modelResults = {};
      _modelErrors = {};
      _modelServices = {};
    });
  }

  void _toggleModelSelection(String model) {
    setState(() {
      if (_selectedModels.contains(model)) {
        _selectedModels.remove(model);
        _modelResults.remove(model);
        _modelErrors.remove(model);
        _modelServices[model]?.dispose();
        _modelServices.remove(model);
      } else {
        _selectedModels.add(model);
        _modelServices[model] = ModelService(model: model);
      }
    });
  }

  Future<void> _analyzeImage() async {
    if (_selectedImage == null || _selectedModels.isEmpty || _originalImage == null) return;
    
    setState(() {
      _isAnalyzing = true;
      _modelResults = {};
      _modelErrors = {};
    });

    for (String model in _selectedModels) {
      final modelService = _modelServices[model];
      if (modelService != null) {
        try {
          await modelService.loadModel();
          final recognitions = await modelService.runInference(_originalImage!);
          
          setState(() {
            _modelResults[model] = recognitions;
            _modelErrors.remove(model);
          });
        } catch (e) {
          print("Error processing model $model: $e");
          setState(() {
            _modelResults[model] = [];
            _modelErrors[model] = e.toString();
          });
        }
      }
    }
    
    setState(() {
      _isAnalyzing = false;
    });
  }

  void _showModelSelectionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Select Detection Model"),
          content: Container(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                _buildModelOption('ssd', 'SSD MobileNet'),
                _buildModelOption('yolo', 'YOLO Tiny'),
                _buildModelOption('mobilenet', 'MobileNet V1'),
                _buildModelOption('mobilenet_v2', 'MobileNet V2'),
                _buildModelOption('mobilenet_v3_large', 'MobileNet V3 Large'),
                _buildModelOption('mobilenet_v3_large_float', 'MobileNet V3 Large Float'),
                _buildModelOption('posenet', 'PoseNet'),
                _buildModelOption('yolov5s', 'YOLOv5s'),
                _buildModelOption('yolov5sdynm', 'YOLOv5s Dynamic Range'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text("Cancel"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildModelOption(String modelKey, String modelName) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _getModelColor(modelKey),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.camera,
            color: Colors.white,
          ),
        ),
        title: Text(modelName),
        trailing: Icon(Icons.arrow_forward_ios),
        onTap: () {
          Navigator.of(context).pop();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CameraScreen(
                cameras: widget.cameras,
                model: modelKey,
              ),
            ),
          );
        },
      ),
    );
  }

  void setRecognitions(List<dynamic> recognitions, int imageHeight, int imageWidth) {
    setState(() {
      _recognitions = recognitions;
      _imageHeight = imageHeight;
      _imageWidth = imageWidth;
    });
  }

  @override
  Widget build(BuildContext context) {
    Size screen = MediaQuery.of(context).size;
    return Scaffold(
      appBar: AppBar(
        title: Text('Object Detection App'),
        backgroundColor: Colors.deepPurple,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.deepPurple.shade50, Colors.white],
          ),
        ),
        child: _selectedImage == null
            ? _buildInitialScreen()
            : _buildImageAnalysisScreen(screen),
      ),
    );
  }

  Widget _buildInitialScreen() {
    return Container(
      height: MediaQuery.of(context).size.height,
      width: MediaQuery.of(context).size.width,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                'Object Detection',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
              SizedBox(height: 40),
              Text(
                'Choose an option to get started',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
              ),
              SizedBox(height: 40),
              _buildOptionButton(
                icon: Icons.camera_alt,
                text: 'Use Camera',
                onPressed: _showModelSelectionDialog,
              ),
              SizedBox(height: 20),
              _buildOptionButton(
                icon: Icons.photo_library,
                text: 'Upload Image',
                onPressed: _pickImage,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionButton({required IconData icon, required String text, required VoidCallback onPressed}) {
    return Container(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.symmetric(vertical: 16),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 4,
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24),
            SizedBox(width: 12),
            Text(text, style: TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }

  Widget _buildImageAnalysisScreen(Size screen) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ImageDisplayComponent(
              selectedImage: _selectedImage,
              imageBytes: _imageBytes,
              modelResults: _modelResults,
              onRemoveImage: _removeImage,
              onAddAnotherImage: _pickImage,
            ),
            SizedBox(height: 24),
            
            Text(
              'Select Detection Models',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildModelChip('ssd'),
                _buildModelChip('yolo'),
                _buildModelChip('mobilenet'),
                _buildModelChip('mobilenet_v2'),
                _buildModelChip('mobilenet_v3_large'),
                _buildModelChip('mobilenet_v3_large_float'),
                _buildModelChip('posenet'),
                _buildModelChip('yolov5s'),
                _buildModelChip('yolov5sdynm'),
              ],
            ),
            SizedBox(height: 24),
            
            if (_selectedModels.isNotEmpty)
              Container(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 4,
                  ),
                  onPressed: _isAnalyzing ? null : _analyzeImage,
                  child: _isAnalyzing
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text('Analyzing...', style: TextStyle(fontSize: 16)),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.analytics, size: 24),
                            SizedBox(width: 12),
                            Text(
                              'Analyze Image',
                              style: TextStyle(fontSize: 18),
                            ),
                          ],
                        ),
                ),
              ),
            SizedBox(height: 24),
            
            if (_modelResults.isNotEmpty) ...[
              Text(
                'Detection Results',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              ..._modelResults.entries.map((entry) {
                return _buildResultCard(entry.key, entry.value);
              }).toList(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildModelChip(String model) {
    final isSelected = _selectedModels.contains(model);
    return FilterChip(
      label: Text(
        _getModelDisplayName(model),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isSelected ? Colors.white : Colors.black,
        ),
      ),
      selected: isSelected,
      onSelected: (_) => _toggleModelSelection(model),
      backgroundColor: Colors.grey.shade200,
      selectedColor: _getModelColor(model),
      checkmarkColor: Colors.white,
      selectedShadowColor: _getModelColor(model),
      elevation: 2,
      pressElevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }

  String _getModelDisplayName(String model) {
    switch (model) {
      case 'mobilenet':
        return 'MobileNet V1';
      case 'mobilenet_v2':
        return 'MobileNet V2';
      case 'mobilenet_v3_large':
        return 'MobileNet V3';
      case 'mobilenet_v3_large_float':
        return 'MobileNet V3 Float';
      default:
        return model;
    }
  }

  Widget _buildResultCard(String model, List<dynamic> recognitions) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getModelColor(model),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _getModelDisplayName(model),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  '${recognitions.length} objects detected',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
            SizedBox(height: 12),
            if (recognitions.isEmpty) ...[
              if (_modelErrors.containsKey(model))
                Text(
                  'Error: ${_modelErrors[model]}',
                  style: TextStyle(color: Colors.red),
                  softWrap: true,
                )
              else
                Text('No objects detected', style: TextStyle(color: Colors.grey)),
            ] else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: recognitions.map((recognition) {
                  final confidence = (recognition['confidence'] * 100).toStringAsFixed(1);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: _getModelColor(model), size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${recognition['label']} - $confidence%',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Color _getModelColor(String model) {
    switch (model) {
      case 'ssd':
        return Colors.blue;
      case 'yolo':
        return Colors.green;
      case 'mobilenet':
        return Colors.orange;
      case 'mobilenet_v2':
        return Colors.deepOrange;
      case 'mobilenet_v3_large':
        return Colors.amber;
      case 'mobilenet_v3_large_float':
        return Colors.yellow.shade700;
      case 'posenet':
        return Colors.purple;
      case 'yolov5s':
        return Colors.red;
      case 'yolov5sdynm':
        return Colors.teal;
      default:
        return Colors.deepPurple;
    }
  }

  @override
  void dispose() {
    _modelServices.values.forEach((service) => service.dispose());
    super.dispose();
  }
}