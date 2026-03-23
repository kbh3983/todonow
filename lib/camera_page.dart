import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isReady = false;
  double _selectedAspectRatio = 1.0; // Default to 1:1
  final List<double> _ratios = [1.0, 4 / 5, 9 / 16];
  final List<String> _ratioLabels = ['1:1', '4:5', '9:16'];

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    _cameras = await availableCameras();
    if (_cameras != null && _cameras!.isNotEmpty) {
      _controller = CameraController(
        _cameras![0],
        ResolutionPreset.high,
        enableAudio: false,
      );

      try {
        await _controller!.initialize();
        if (mounted) {
          setState(() {
            _isReady = true;
          });
        }
      } catch (e) {
        debugPrint('Camera Error: $e');
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      final XFile photo = await _controller!.takePicture();

      // Crop the image according to the selected aspect ratio
      final croppedPath = await _cropImage(photo.path);

      if (mounted) {
        Navigator.pop(context, croppedPath);
      }
    } catch (e) {
      debugPrint('Error taking picture: $e');
    }
  }

  Future<String> _cropImage(String imagePath) async {
    final bytes = await File(imagePath).readAsBytes();
    img.Image? image = img.decodeImage(bytes);

    if (image == null) return imagePath;

    int width = image.width;
    int height = image.height;
    int targetWidth, targetHeight;
    int x = 0, y = 0;

    // We assume the camera captures in its native ratio (usually 4:3 or 16:9)
    // We want to crop to the center based on _selectedAspectRatio
    if (width / height > _selectedAspectRatio) {
      // Image is wider than target ratio
      targetHeight = height;
      targetWidth = (height * _selectedAspectRatio).toInt();
      x = (width - targetWidth) ~/ 2;
    } else {
      // Image is taller than target ratio
      targetWidth = width;
      targetHeight = (width / _selectedAspectRatio).toInt();
      y = (height - targetHeight) ~/ 2;
    }

    img.Image cropped = img.copyCrop(
      image,
      x: x,
      y: y,
      width: targetWidth,
      height: targetHeight,
    );

    final tempDir = await getTemporaryDirectory();
    final fileName = 'cropped_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final croppedFile = File(path.join(tempDir.path, fileName));
    await croppedFile.writeAsBytes(img.encodeJpg(cropped));

    return croppedFile.path;
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady || _controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF6366F1)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera Preview
          Center(
            child: AspectRatio(
              aspectRatio: 1 / _controller!.value.aspectRatio,
              child: CameraPreview(_controller!),
            ),
          ),

          // Ratio Selector Overlay (Optional: blurred masking)
          _buildMask(),

          // UI Controls
          SafeArea(
            child: Column(
              children: [
                // Top Bar: Back & Ratio Selection
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 28,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          children: List.generate(_ratios.length, (index) {
                            bool isSelected =
                                _selectedAspectRatio == _ratios[index];
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedAspectRatio = _ratios[index];
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF6366F1)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _ratioLabels[index],
                                  style: GoogleFonts.inter(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.white.withOpacity(0.5),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(width: 48), // Spacer for balance
                    ],
                  ),
                ),

                const Spacer(),

                // Bottom Bar: Shutter Button
                Padding(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _takePicture,
                        child: Container(
                          width: 80,
                          height: 80,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                          ),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Color(0xFF6366F1),
                              size: 32,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'TAP TO CAPTURE',
                        style: GoogleFonts.inter(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMask() {
    // This creates a visual mask to show what will be cropped
    return LayoutBuilder(
      builder: (context, constraints) {
        double screenWidth = constraints.maxWidth;
        double screenHeight = constraints.maxHeight;

        double previewHeight = screenWidth / _selectedAspectRatio;
        double topOffset = (screenHeight - previewHeight) / 2;

        return Stack(
          children: [
            // Top Shade
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: topOffset,
              child: Container(color: Colors.black.withOpacity(0.7)),
            ),
            // Bottom Shade
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: screenHeight - topOffset - previewHeight,
              child: Container(color: Colors.black.withOpacity(0.7)),
            ),
            // Middle area remains clear (the crop area)
            Center(
              child: Container(
                width: screenWidth,
                height: previewHeight,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white24, width: 1),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
