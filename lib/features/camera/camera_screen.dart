import 'dart:async'; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import '../../services/native_camera_service.dart'; 
import '../../models/ai_recommendation.dart'; 
import '../../data/photo_storage.dart'; 
// ✅ 引用统一的常量文件
import '../editor/editor_constants.dart';
import '../editor/widgets/unified_editor_panel.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});
  static const route = '/camera';

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with TickerProviderStateMixin {
  String _flashMode = "off";
  final NativeCameraService _cameraService = NativeCameraService();
  bool _isShooting = false;
  String _currentRatio = "4:3"; 
  
  // 使用统一定义的 EditorMode
  EditorMode _editorMode = EditorMode.none; 
  
  double _filterIntensity = 80.0;
  int _timerDuration = 0;
  bool _isCountingDown = false;
  int _currentCount = 0;

  late AnimationController _galleryAnimController;
  late Animation<double> _galleryScaleAnim;

  late AnimationController _aiFadeController;
  String _lastAiMessage = "";
  AiRecommendation? _currentRecommendation;
  Timer? _aiHideTimer;

  @override
  void initState() {
    super.initState();
    _galleryAnimController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 150),
    );
    _galleryScaleAnim = Tween<double>(begin: 1.0, end: 0.7).animate(
      CurvedAnimation(parent: _galleryAnimController, curve: Curves.easeInOut),
    );

    _aiFadeController = AnimationController(vsync: this, duration: const Duration(seconds: 2), value: 0.0);

    _cameraService.aiStream.listen((data) async {
      final prefs = await SharedPreferences.getInstance();
      final bool isAiEnabled = prefs.getBool('enable_ai_recommendation') ?? true;
      if (isAiEnabled) {
        _handleNewAiData(data);
      }
    });
  }

  void _handleNewAiData(AiRecommendation data) {
    if (!mounted) return;
    if (data.message.isEmpty) return;

    if (data.message != _lastAiMessage) {
      setState(() {
        _lastAiMessage = data.message;
        _currentRecommendation = data;
      });

      _aiFadeController.value = 1.0; 
      _aiHideTimer?.cancel();
      _aiHideTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) _aiFadeController.reverse();
      });
    }
  }

  @override
  void dispose() {
    _galleryAnimController.dispose();
    _aiFadeController.dispose();
    _aiHideTimer?.cancel();
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
    final double maskHeight = _currentRatio == "1:1" ? (viewfinderHeight - screenWidth) / 2 : 0.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),

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
                  
                  // 遮罩
                  Column(
                    children: [
                      AnimatedContainer(duration: const Duration(milliseconds: 300), height: maskHeight, width: double.infinity, color: Colors.black),
                      const Spacer(),
                      AnimatedContainer(duration: const Duration(milliseconds: 300), height: maskHeight, width: double.infinity, color: Colors.black),
                    ],
                  ),

                  // AI 气泡
                  Positioned(
                    bottom: 40 + maskHeight, 
                    left: 20, right: 20,
                    child: FadeTransition(
                      opacity: _aiFadeController,
                      child: _currentRecommendation != null ? _buildNewAiBubble(_currentRecommendation!) : const SizedBox(),
                    ),
                  ),

                  // 独立滑杆 (仅在滤镜模式下显示)
                  if (_editorMode == EditorMode.filter)
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 300),
                      bottom: 10 + maskHeight, 
                      left: 20, right: 20,
                      child: _buildIndependentSlider(),
                    ),

                  if (_isCountingDown)
                    Center(
                      child: Text("$_currentCount", style: const TextStyle(color: Colors.white, fontSize: 100, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 10, color: Colors.black)])),
                    ),
                ],
              ),
            ),

            Expanded(
              child: Container(
                color: const Color(0xFF111111),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // 底部面板切换区域
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (Widget child, Animation<double> animation) {
                        return SlideTransition(
                          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(animation),
                          child: child,
                        );
                      },
                      child: _buildBottomPanelContent(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 顶部栏 ---
  Widget _buildTopBar() {
    if (_editorMode != EditorMode.none) return const SizedBox(height: 50);
    
    return Container(
      height: 50, color: Colors.black,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(icon: const Icon(Icons.settings, color: Colors.white), onPressed: () => Navigator.pushNamed(context, '/settings')),
          
          GestureDetector(
            onTap: () {
              setState(() {
                if (_timerDuration == 0) _timerDuration = 3;
                else if (_timerDuration == 3) _timerDuration = 7;
                else _timerDuration = 0;
              });
            },
            child: Container(
              width: 24, alignment: Alignment.center,
              child: _timerDuration == 0
                  ? const Icon(Icons.timer_off, color: Colors.white)
                  : Text("${_timerDuration}s", style: const TextStyle(color: Colors.yellowAccent, fontWeight: FontWeight.bold)),
            ),
          ),

          IconButton(icon: Icon(_flashMode == 'on' ? Icons.flash_on : Icons.flash_off, color: Colors.white), onPressed: () {
             final newMode = _flashMode == 'off' ? 'auto' : (_flashMode == 'auto' ? 'on' : 'off');
             setState(() => _flashMode = newMode);
             _cameraService.setFlashMode(newMode);
          }),
          
          TextButton(onPressed: () => setState(() => _currentRatio = (_currentRatio == "4:3") ? "1:1" : "4:3"), 
            child: Text(_currentRatio, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          
          IconButton(icon: const Icon(Icons.flip_camera_ios, color: Colors.white), onPressed: () => _cameraService.switchCamera()),
        ],
      ),
    );
  }

  // --- 底部面板内容分发 ---
  Widget _buildBottomPanelContent() {
    // 统一处理 Panel，根据 mode 传不同的数据
    if (_editorMode != EditorMode.none) {
      List<EditorCategory> categories = [];
      Key key = const ValueKey('Empty');

      switch (_editorMode) {
        case EditorMode.filter:
          categories = EditorMockData.filterCategories;
          key = const ValueKey('FilterPanel');
          break;
        case EditorMode.frame:
          categories = EditorMockData.frameCategories;
          key = const ValueKey('FramePanel');
          break;
        case EditorMode.sticker:
          categories = EditorMockData.stickerCategories; // ✅ 修正：使用 stickerCategories
          key = const ValueKey('StickerPanel');
          break;
        case EditorMode.grain:
          categories = EditorMockData.grainCategories;   // ✅ 新增：使用 grainCategories
          key = const ValueKey('GrainPanel');
          break;
        default: break;
      }

      return UnifiedEditorPanel(
        key: key,
        categories: categories,
        onClose: () => setState(() => _editorMode = EditorMode.none),
      );
    }

    // 默认显示拍照面板
    return _buildCapturePanel();
  }

  // --- 拍照主面板 ---
  Widget _buildCapturePanel() {
    return Container(
      key: const ValueKey('CapturePanel'),
      padding: const EdgeInsets.only(bottom: 20, top: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. 功能图标栏 (4个)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween, // 均匀分布
              children: [
                _buildFeatureIcon(Icons.crop_free, "边框", () => setState(() => _editorMode = EditorMode.frame)),
                _buildFeatureIcon(Icons.face, "贴纸", () => setState(() => _editorMode = EditorMode.sticker)),
                // ✅ 新增：颗粒入口
                _buildFeatureIcon(Icons.grain, "颗粒", () => setState(() => _editorMode = EditorMode.grain)),
                _buildFeatureIcon(Icons.color_lens, "滤镜", () => setState(() => _editorMode = EditorMode.filter)),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // 2. 快门与相册入口
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
                  child: _isShooting ? const Center(child: CircularProgressIndicator(color: Colors.white)) : null,
                ),
              ),
              // 右侧占位 (保持快门居中)
              const SizedBox(width: 48), 
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureIcon(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 24), 
          const SizedBox(height: 4), 
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 10))
        ],
      ),
    );
  }

  // ... (其他逻辑不变：拍照、AI气泡、滑杆) ...
  Future<void> _handleShutterPress() async {
    if (_isShooting || _isCountingDown) return;
    if (_timerDuration > 0) {
      setState(() { _isCountingDown = true; _currentCount = _timerDuration; });
      Timer.periodic(const Duration(seconds: 1), (timer) async {
        if (_currentCount > 1) { setState(() => _currentCount--); } 
        else { timer.cancel(); setState(() => _isCountingDown = false); await _performCapture(); }
      });
    } else { await _performCapture(); }
  }

  Future<void> _performCapture() async {
    setState(() => _isShooting = true);
    try {
      final path = await _cameraService.takePhoto(_currentRatio);
      if (path.isEmpty) { _showErrorDialog("存储空间已满", "无法写入临时文件。"); return; }
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('auto_save_to_gallery') ?? true) await _cameraService.saveToGallery(path);
      await PhotoStorage.savePhoto(path);
      _runGalleryAnimation();
    } catch (e) { _showErrorDialog("未知错误", "Error: $e"); } 
    finally { if (mounted) setState(() => _isShooting = false); }
  }

  Widget _buildNewAiBubble(AiRecommendation data) {
    // 简化的 AI 气泡 UI
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.yellowAccent)),
      child: Text("${data.message} (智能推荐)", style: const TextStyle(color: Colors.white)),
    );
  }

  Widget _buildIndependentSlider() {
    return Row(
      children: [
        const Icon(Icons.tune, color: Colors.white, size: 16),
        Expanded(child: Slider(value: _filterIntensity, min: 0, max: 100, activeColor: Colors.yellowAccent, onChanged: (v) => setState(() => _filterIntensity = v))),
      ],
    );
  }

  void _showErrorDialog(String title, String content) {
    showDialog(context: context, builder: (ctx) => AlertDialog(title: Text(title), content: Text(content), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))]));
  }
}