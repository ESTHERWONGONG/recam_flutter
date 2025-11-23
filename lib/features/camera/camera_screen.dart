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

// ✅ [修改 1] 加上 SingleTickerProviderStateMixin (为了动画)
class _CameraScreenState extends State<CameraScreen> with SingleTickerProviderStateMixin {
  bool _isFilterMode = false;
  String _flashMode = "off";
  Stream<AiRecommendation>? _aiStream;
  final NativeCameraService _cameraService = NativeCameraService();
  bool _isShooting = false;

  // ✅ [修改 2] 定义动画控制器
  late AnimationController _galleryAnimController;
  late Animation<double> _galleryScaleAnim;

  @override
  void initState() {
    super.initState();
    _aiStream = _cameraService.aiStream;

    // ✅ [修改 3] 初始化动画：0.2秒内完成 缩放效果
    _galleryAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150), // 速度快一点，Q弹
    );
    
    // 定义动画曲线：从 1.0 缩小到 0.7，再弹回 1.0
    _galleryScaleAnim = Tween<double>(begin: 1.0, end: 0.7).animate(
      CurvedAnimation(parent: _galleryAnimController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _galleryAnimController.dispose(); // 记得销毁
    super.dispose();
  }

  // ✅ [修改 4] 执行动画的函数
  Future<void> _runGalleryAnimation() async {
    await _galleryAnimController.forward(); // 缩小
    await _galleryAnimController.reverse(); // 弹回
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final viewfinderHeight = screenWidth * (4 / 3);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: Center(
                child: SizedBox(
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
                      _buildAiBubble(),
                      Positioned(
                        bottom: 16,
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
              ),
            ),
            Container(
              height: 160,
              color: const Color(0xFF111111),
              child: _isFilterMode ? _buildFilterPanel() : _buildCapturePanel(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiBubble() {
    return Positioned(
      top: 20,
      right: 16,
      child: StreamBuilder<AiRecommendation>(
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
      ),
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
          const Text("3:4", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
        // ✅ [修改 5] 给相册按钮加动画包裹
        ScaleTransition(
          scale: _galleryScaleAnim,
          child: IconButton(
            icon: const Icon(Icons.photo_library, color: Colors.white, size: 32),
            onPressed: () => Navigator.pushNamed(context, '/gallery'),
          ),
        ),
        
        // 📸 快门按钮
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

  // ✅ [修改 6] 只有动画，没有 SnackBar 提示了
  Future<void> _handleShutterPress() async {
    if (_isShooting) return;
    setState(() => _isShooting = true);

    try {
      print("📸 1. 开始拍照...");
      final path = await _cameraService.takePhoto();

      if (path.isEmpty) {
        _showErrorDialog("存储空间已满", "无法写入临时文件。");
        return;
      }

      // 读取配置
      final prefs = await SharedPreferences.getInstance();
      final bool autoSave = prefs.getBool('auto_save_to_gallery') ?? true;

      // 逻辑：
      // 1. 如果开了开关 -> 尝试存系统相册
      if (autoSave) {
        await _cameraService.saveToGallery(path);
        // 即使系统相册存失败了，也不弹窗打断用户，反正 App 内还有备份
      }

      // 2. App 内必须记账 (这是你的要求：不管怎样都要存后台)
      await PhotoStorage.savePhoto(path);
      
      // 3. 触发左下角动画 (反馈：已搞定)
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