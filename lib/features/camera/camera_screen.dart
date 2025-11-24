import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import '../../services/native_camera_service.dart'; 
import '../../models/ai_recommendation.dart'; 
import '../../data/photo_storage.dart'; 
// 引入编辑面板模块
import '../editor/editor_constants.dart';
import '../editor/widgets/unified_editor_panel.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});
  static const route = '/camera';

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with SingleTickerProviderStateMixin {
  // 状态管理
  String _flashMode = "off";
  Stream<AiRecommendation>? _aiStream;
  final NativeCameraService _cameraService = NativeCameraService();
  bool _isShooting = false;
  String _currentRatio = "4:3"; 

  // 编辑模式状态
  EditorMode _editorMode = EditorMode.none; 

  // 动画控制器
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
    final viewfinderHeight = screenWidth * (4 / 3);
    
    // 计算遮罩高度
    final double maskHeight = _currentRatio == "1:1" 
        ? (viewfinderHeight - screenWidth) / 2 
        : 0.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // 1. 顶部工具栏
            _buildTopBar(),

            // 2. 中间取景框
            SizedBox(
              width: screenWidth,
              height: viewfinderHeight,
              child: Stack(
                children: [
                  // A. 原生视图
                  const UiKitView(
                    viewType: 'recam_native_camera_view',
                    layoutDirection: TextDirection.ltr,
                    creationParams: {},
                    creationParamsCodec: StandardMessageCodec(),
                  ),
                  
                  // B. 遮罩层
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

                  // C. AI 气泡 (✅ 这就是报错缺少的那个方法调用)
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 300),
                    top: 20 + maskHeight,
                    right: 16,
                    child: _buildAiBubbleContent(), 
                  ),
                  
                  // D. 变焦按钮 (非编辑模式下显示)
                  if (_editorMode == EditorMode.none)
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

            // 3. 底部操作区 (支持动画切换)
            Expanded(
              child: Container(
                color: const Color(0xFF111111),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 1),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    );
                  },
                  child: _buildBottomPanel(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ 核心逻辑：底部面板路由
  Widget _buildBottomPanel() {
    switch (_editorMode) {
      case EditorMode.filter:
        return UnifiedEditorPanel(
          key: const ValueKey('FilterPanel'),
          categories: EditorMockData.filterCategories,
          showSlider: true,
          onClose: () => setState(() => _editorMode = EditorMode.none),
        );
      case EditorMode.frame:
        return UnifiedEditorPanel(
          key: const ValueKey('FramePanel'),
          categories: EditorMockData.frameCategories,
          showSlider: false,
          onClose: () => setState(() => _editorMode = EditorMode.none),
        );
      case EditorMode.sticker:
        return UnifiedEditorPanel(
          key: const ValueKey('StickerPanel'),
          categories: EditorMockData.frameCategories, // 暂用假数据
          showSlider: false,
          onClose: () => setState(() => _editorMode = EditorMode.none),
        );
      case EditorMode.none:
      default:
        return _buildCapturePanel();
    }
  }

  // ✅ 拍摄模式面板
  Widget _buildCapturePanel() {
    return Container(
      key: const ValueKey('CapturePanel'),
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // 功能入口
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildFeatureIcon(Icons.crop_free, "边框", () => setState(() => _editorMode = EditorMode.frame)),
              _buildFeatureIcon(Icons.face, "贴纸", () => setState(() => _editorMode = EditorMode.sticker)),
              _buildFeatureIcon(Icons.color_lens, "滤镜", () => setState(() => _editorMode = EditorMode.filter)),
            ],
          ),
          const SizedBox(height: 20),
          // 快门区域
          Row(
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
              const SizedBox(width: 40), // 占位平衡
            ],
          ),
        ],
      ),
    );
  }

  // ✅ [修复] 之前报错缺失的方法：AI 气泡组件
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
    // 非编辑模式才显示顶部栏，或者保持显示但禁用
    if (_editorMode != EditorMode.none) return const SizedBox(height: 50); 

    return Container(
      height: 50,
      color: Colors.black,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white), 
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
          IconButton(
            icon: Icon(_flashMode == 'on' ? Icons.flash_on : Icons.flash_off, color: Colors.white),
            onPressed: () {
              final newMode = _flashMode == 'off' ? 'auto' : (_flashMode == 'auto' ? 'on' : 'off');
              setState(() => _flashMode = newMode);
              _cameraService.setFlashMode(newMode);
            },
          ),
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

  // 辅助小组件
  Widget _buildFeatureIcon(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 10)),
        ],
      ),
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
      if (autoSave) await _cameraService.saveToGallery(path);
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("知道了")),
        ],
      ),
    );
  }
}