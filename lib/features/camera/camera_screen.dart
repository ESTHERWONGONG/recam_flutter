import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/native_camera_service.dart'; 
import '../../models/ai_recommendation.dart'; 
import '../../data/photo_storage.dart'; 

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});
  static const route = '/camera';

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  bool _isFilterMode = false;
  String _flashMode = "off";
  Stream<AiRecommendation>? _aiStream;
  final NativeCameraService _cameraService = NativeCameraService();

  // 防止连点快门，增加一个由锁
  bool _isShooting = false;

  @override
  void initState() {
    super.initState();
    _aiStream = _cameraService.aiStream;
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
                      // 变焦按钮
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

  // --- 组件拆分 ---

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
        IconButton(
          icon: const Icon(Icons.photo_library, color: Colors.white, size: 32),
          onPressed: () => Navigator.pushNamed(context, '/gallery'),
        ),
        
        // 📸 快门按钮 (核心逻辑修改)
        GestureDetector(
          onTap: _handleShutterPress, // 抽离出逻辑函数
          child: Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isShooting ? Colors.grey : const Color(0xFFCE2029), // 拍摄中变灰
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

  // ✅ 新的拍照流程逻辑 (V1.3.1)
  Future<void> _handleShutterPress() async {
    if (_isShooting) return; // 防止连点
    setState(() => _isShooting = true);

    try {
      print("📸 1. 开始拍照...");
      // 1. 拍照存临时文件
      final path = await _cameraService.takePhoto();

      if (path.isEmpty) {
        // 边界情况 1: 拍照都没成功（可能是磁盘满了连临时文件都写不进去）
        _showErrorDialog("存储空间已满", "无法写入临时文件，请清理手机空间。");
        return;
      }

      print("📸 2. 存入系统相册...");
      // 2. 自动保存到系统相册
      final isSavedToSystem = await _cameraService.saveToGallery(path);

      if (!isSavedToSystem) {
        // 边界情况 2: 系统相册保存失败 (可能是权限 或 磁盘满)
        // 注意：Swift 那边如果没权限或存失败会返回 false
        _showErrorDialog("保存失败", "无法保存到相册。\n请检查：\n1. 手机存储空间是否已满\n2. 设置中是否允许 ReCam 访问相册");
      } else {
        // 3. 只有系统保存成功了，才记录到 App 相册 (保持一致性)
        await PhotoStorage.savePhoto(path);
        
        // 4. 给个轻提示，不打断用户连拍
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ 已保存'), 
              duration: Duration(milliseconds: 800),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.green,
            ),
          );
        }
      }

    } catch (e) {
      _showErrorDialog("未知错误", "拍摄过程中发生错误: $e");
    } finally {
      if (mounted) setState(() => _isShooting = false);
    }
  }

  // ⚠️ 强弹窗：存储空间不足或权限问题
  void _showErrorDialog(String title, String content) {
    showDialog(
      context: context,
      barrierDismissible: false, // 用户必须点确认
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