import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import '../../services/native_camera_service.dart'; 
import '../../models/ai_recommendation.dart'; 
import '../../data/photo_storage.dart'; 

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});
  static const route = '/camera';

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with SingleTickerProviderStateMixin {
  bool _isFilterMode = false;
  String _flashMode = "off";
  Stream<AiRecommendation>? _aiStream;
  final NativeCameraService _cameraService = NativeCameraService();
  bool _isShooting = false;

  // ✅ [修改] 默认改为 "4:3" (符合行业惯例)
  String _currentRatio = "4:3"; 

  late AnimationController _galleryAnimController;
  late Animation<double> _galleryScaleAnim;

  @override
  void initState() {
    super.initState();
    _aiStream = _cameraService.aiStream;
    _galleryAnimController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 150),
    );
    _galleryScaleAnim = Tween<double>(begin: 1.0, end: 0.7).animate(
      CurvedAnimation(parent: _galleryAnimController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _galleryAnimController.dispose();
    super.dispose();
  }

  Future<void> _runGalleryAnimation() async {
    await _galleryAnimController.forward();
    await _galleryAnimController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // 📷 这里计算依然是用 4/3 (也就是 Height = Width * 1.33)，保持竖屏长方形
    final viewfinderHeight = screenWidth * (4 / 3);
    
    final double maskHeight = _currentRatio == "1:1" 
        ? (viewfinderHeight - screenWidth) / 2 
        : 0.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            // 取景框部分 (保持不变)
            SizedBox(
              width: screenWidth,
              height: viewfinderHeight,
              child: Stack(
                children: [
                  const UiKitView(
                    viewType: 'recam_native_camera_view',
                    layoutDirection: TextDirection.ltr,
                    creationParams: {},
                    creationParamsCodec: StandardMessageCodec(),
                  ),
                  Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: maskHeight,
                        width: double.infinity,
                        color: Colors.black,
                      ),
                      const Spacer(),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: maskHeight,
                        width: double.infinity,
                        color: Colors.black,
                      ),
                    ],
                  ),
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 300),
                    top: 20 + maskHeight,
                    right: 16,
                    child: _buildAiBubbleContent(),
                  ),
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 300),
                    bottom: 16 + maskHeight,
                    left: 0, right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildZoomBtn(0.5),
                        const SizedBox(width: 24),
                        _buildZoomBtn(1.0),
                        const SizedBox(width: 24),
                        _buildZoomBtn(2.0),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                color: const Color(0xFF111111),
                child: _isFilterMode ? _buildFilterPanel() : _buildCapturePanel(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiBubbleContent() {
    return StreamBuilder<AiRecommendation>(
      stream: _aiStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final recommendation = snapshot.data!;
        if (recommendation.message.isEmpty) return const SizedBox();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.yellowAccent.withOpacity(0.8)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_awesome, color: Colors.yellowAccent, size: 16),
              const SizedBox(width: 6),
              Text(
                recommendation.message, 
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 50,
      color: Colors.black,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(icon: const Icon(Icons.settings, color: Colors.white), onPressed: () {}),
          IconButton(
            icon: Icon(_flashMode == 'on' ? Icons.flash_on : Icons.flash_off, color: Colors.white),
            onPressed: () {
              final newMode = _flashMode == 'off' ? 'auto' : (_flashMode == 'auto' ? 'on' : 'off');
              setState(() => _flashMode = newMode);
              _cameraService.setFlashMode(newMode);
            },
          ),
          // ✅ [修改] 按钮逻辑：4:3 <-> 1:1
          TextButton(
            onPressed: () {
              setState(() {
                _currentRatio = (_currentRatio == "4:3") ? "1:1" : "4:3";
              });
            }, 
            child: Text(_currentRatio, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios, color: Colors.white), 
            onPressed: () => _cameraService.switchCamera()
          ),
        ],
      ),
    );
  }

  Widget _buildCapturePanel() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ScaleTransition(
          scale: _galleryScaleAnim,
          child: IconButton(
            icon: const Icon(Icons.photo_library, color: Colors.white, size: 32),
            onPressed: () => Navigator.pushNamed(context, '/gallery'),
          ),
        ),
        GestureDetector(
          onTap: _handleShutterPress,
          child: Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isShooting ? Colors.grey : const Color(0xFFCE2029),
              border: Border.all(color: Colors.white, width: 4),
            ),
            child: _isShooting 
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : null,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.filter_vintage, color: Colors.yellowAccent, size: 32),
          onPressed: () => setState(() => _isFilterMode = true),
        ),
      ],
    );
  }

  Future<void> _handleShutterPress() async {
    if (_isShooting) return;
    setState(() => _isShooting = true);

    try {
      print("📸 1. 开始拍照 (比例: $_currentRatio)...");
      final path = await _cameraService.takePhoto(_currentRatio);

      if (path.isEmpty) {
        _showErrorDialog("存储空间已满", "无法写入临时文件。");
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final bool autoSave = prefs.getBool('auto_save_to_gallery') ?? true;

      if (autoSave) {
        await _cameraService.saveToGallery(path);
      }

      await PhotoStorage.savePhoto(path);
      _runGalleryAnimation();

    } catch (e) {
      _showErrorDialog("未知错误", "Error: $e");
    } finally {
      if (mounted) setState(() => _isShooting = false);
    }
  }

  void _showErrorDialog(String title, String content) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(color: Colors.red)),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("知道了"),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPanel() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("选择胶片", style: TextStyle(color: Colors.white)),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(5, (index) => Container(
              margin: const EdgeInsets.all(8),
              width: 60, height: 60,
              color: Colors.grey[800],
              child: Center(child: Text("C$index", style: const TextStyle(color: Colors.white))),
            )),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
          onPressed: () => setState(() => _isFilterMode = false),
        )
      ],
    );
  }

  Widget _buildZoomBtn(double zoom) {
    return GestureDetector(
      onTap: () => _cameraService.setZoom(zoom),
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withOpacity(0.5),
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        alignment: Alignment.center,
        child: Text("${zoom}x", style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    );
  }
}