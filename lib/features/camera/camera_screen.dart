import 'dart:async'; 
import 'dart:io';
import 'dart:typed_data'; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart'; 
import 'package:screenshot/screenshot.dart';       
import 'package:shared_preferences/shared_preferences.dart'; 
import '../../services/native_camera_service.dart'; 
import '../../models/ai_recommendation.dart'; 
import '../../data/photo_storage.dart'; 
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
  final ScreenshotController _screenshotController = ScreenshotController();

  bool _isShooting = false;
  String _currentRatio = "4:3"; 
  EditorMode _editorMode = EditorMode.none; 
  
  String _selectedFilterId = "none";
  String _selectedFrameId = "none";
  String _selectedStickerId = "none";
  String _selectedGrainId = "none";

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
    _galleryAnimController = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _galleryScaleAnim = Tween<double>(begin: 1.0, end: 0.7).animate(CurvedAnimation(parent: _galleryAnimController, curve: Curves.easeInOut));
    _aiFadeController = AnimationController(vsync: this, duration: const Duration(seconds: 2), value: 0.0);
    
    _cameraService.aiStream.listen((data) async {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('enable_ai_recommendation') ?? true) _handleNewAiData(data);
    });
  }

  void _handleNewAiData(AiRecommendation data) {
    if (!mounted || data.message.isEmpty) return;
    if (data.message != _lastAiMessage) {
      setState(() { _lastAiMessage = data.message; _currentRecommendation = data; });
      _aiFadeController.value = 1.0; 
      _aiHideTimer?.cancel();
      _aiHideTimer = Timer(const Duration(seconds: 3), () { if (mounted) _aiFadeController.reverse(); });
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

  // ✅ 辅助方法：获取资源路径
  String? _getAssetPath(List<EditorCategory> categories, String id) {
    if (id == 'none') return null;
    for (var cat in categories) {
      for (var item in cat.items) {
        if (item.id == id) return item.assetPath;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final viewfinderHeight = screenWidth * (4 / 3);
    final double maskHeight = _currentRatio == "1:1" ? (viewfinderHeight - screenWidth) / 2 : 0.0;

    // 获取当前选中的资源路径
    final stickerPath = _getAssetPath(EditorMockData.stickerCategories, _selectedStickerId);
    final framePath = _getAssetPath(EditorMockData.frameCategories, _selectedFrameId);
    final grainPath = _getAssetPath(EditorMockData.grainCategories, _selectedGrainId);

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            // 1. 主内容
            Column(
              children: [
                _buildTopBar(),
                SizedBox(
                  width: screenWidth,
                  height: viewfinderHeight,
                  child: Stack(
                    children: [
                      // 相机预览
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
                      
                      // --- 实时预览层 ---
                      // 3.1 滤镜 (模拟)
                      if (_selectedFilterId == 'f_c200')
                         IgnorePointer(child: Container(color: Colors.orange.withOpacity(0.05))),

                      // 3.2 颗粒/光效
                      if (grainPath != null && grainPath.isNotEmpty)
                        IgnorePointer(
                          child: Image.asset(
                            grainPath, 
                            fit: BoxFit.cover, 
                            width: double.infinity,
                            height: double.infinity,
                            color: Colors.white.withOpacity(0.5),
                            colorBlendMode: BlendMode.screen,
                            errorBuilder: (c,e,s) => const SizedBox(),
                          )
                        ),

                      // 3.3 边框 (拉伸填满)
                      if (framePath != null && framePath.isNotEmpty)
                        IgnorePointer(
                          child: Image.asset(framePath, fit: BoxFit.fill, width: double.infinity, height: double.infinity, errorBuilder: (c,e,s) => const SizedBox())
                        ),

                      // 3.4 贴纸 (✅ 固定在右下角，水印风格)
                      if (stickerPath != null && stickerPath.isNotEmpty)
                        Positioned(
                          bottom: 30,
                          right: 30,
                          child: IgnorePointer(
                            child: Image.asset(
                              stickerPath, 
                              width: 100, // 尺寸适中
                              fit: BoxFit.contain, 
                              errorBuilder: (c,e,s) => const SizedBox()
                            ),
                          ),
                        ),

                      // AI 气泡
                      Positioned(
                        bottom: 40 + maskHeight, left: 20, right: 20,
                        child: FadeTransition(
                          opacity: _aiFadeController,
                          child: _currentRecommendation != null ? _buildNewAiBubble(_currentRecommendation!) : const SizedBox(),
                        ),
                      ),
                      
                      // 滑杆
                      if (_editorMode == EditorMode.filter)
                        AnimatedPositioned(duration: const Duration(milliseconds: 300), bottom: 10 + maskHeight, left: 20, right: 20, child: _buildIndependentSlider()),
                      
                      // 倒计时
                      if (_isCountingDown)
                        Center(child: Text("$_currentCount", style: const TextStyle(color: Colors.white, fontSize: 100, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 10, color: Colors.black)]))),
                    ],
                  ),
                ),
                const Spacer(),
              ],
            ),

            // 2. 底部交互区
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: Container(
                color: const Color(0xFF111111),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    return SlideTransition(
                      position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(animation),
                      child: child,
                    );
                  },
                  child: _buildBottomPanelContent(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 组件构建方法
  // ==========================================

  Widget _buildTopBar() {
    if (_editorMode != EditorMode.none) return const SizedBox(height: 50);
    return Container(
      height: 50, color: Colors.black,
      child: SafeArea(
        top: true, bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(icon: const Icon(Icons.settings, color: Colors.white), onPressed: () => Navigator.pushNamed(context, '/settings')),
            GestureDetector(
              onTap: () { setState(() { if (_timerDuration == 0) _timerDuration = 3; else if (_timerDuration == 3) _timerDuration = 7; else _timerDuration = 0; }); },
              child: Container(width: 24, alignment: Alignment.center, child: _timerDuration == 0 ? const Icon(Icons.timer_off, color: Colors.white) : Text("${_timerDuration}s", style: const TextStyle(color: Colors.yellowAccent, fontWeight: FontWeight.bold))),
            ),
            IconButton(icon: Icon(_flashMode == 'on' ? Icons.flash_on : Icons.flash_off, color: Colors.white), onPressed: () { final newMode = _flashMode == 'off' ? 'auto' : (_flashMode == 'auto' ? 'on' : 'off'); setState(() => _flashMode = newMode); _cameraService.setFlashMode(newMode); }),
            TextButton(onPressed: () => setState(() => _currentRatio = (_currentRatio == "4:3") ? "1:1" : "4:3"), child: Text(_currentRatio, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            IconButton(icon: const Icon(Icons.flip_camera_ios, color: Colors.white), onPressed: () => _cameraService.switchCamera()),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomPanelContent() {
    if (_editorMode != EditorMode.none) {
      List<EditorCategory> categories = [];
      Key key = const ValueKey('Empty');
      switch (_editorMode) {
        case EditorMode.filter: categories = EditorMockData.filterCategories; key = const ValueKey('FilterPanel'); break;
        case EditorMode.frame: categories = EditorMockData.frameCategories; key = const ValueKey('FramePanel'); break;
        case EditorMode.sticker: categories = EditorMockData.stickerCategories; key = const ValueKey('StickerPanel'); break;
        case EditorMode.grain: categories = EditorMockData.grainCategories; key = const ValueKey('GrainPanel'); break;
        default: break;
      }
      
      return SafeArea(
        top: false,
        child: UnifiedEditorPanel(
          key: key,
          categories: categories,
          onClose: () => setState(() => _editorMode = EditorMode.none),
          onItemTap: (item) {
            setState(() {
              if (_editorMode == EditorMode.filter) _selectedFilterId = item.id;
              if (_editorMode == EditorMode.frame) _selectedFrameId = item.id;
              if (_editorMode == EditorMode.sticker) _selectedStickerId = item.id;
              if (_editorMode == EditorMode.grain) _selectedGrainId = item.id;
            });
            print("📸 选中: ${item.name}");
          },
        ),
      );
    }
    return _buildCapturePanel();
  }

  Widget _buildCapturePanel() {
    return SafeArea(
      top: false,
      child: Container(
        key: const ValueKey('CapturePanel'),
        padding: const EdgeInsets.only(bottom: 20, top: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildFeatureIcon(Icons.crop_free, "边框", () => setState(() => _editorMode = EditorMode.frame), isActive: _selectedFrameId != 'none'),
                  _buildFeatureIcon(Icons.face, "贴纸", () => setState(() => _editorMode = EditorMode.sticker), isActive: _selectedStickerId != 'none'),
                  _buildFeatureIcon(Icons.grain, "颗粒", () => setState(() => _editorMode = EditorMode.grain), isActive: _selectedGrainId != 'none'),
                  _buildFeatureIcon(Icons.color_lens, "滤镜", () => setState(() => _editorMode = EditorMode.filter), isActive: _selectedFilterId != 'none'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ScaleTransition(scale: _galleryScaleAnim, child: IconButton(icon: const Icon(Icons.photo_library, color: Colors.white, size: 32), onPressed: () => Navigator.pushNamed(context, '/gallery'))),
                GestureDetector(
                  onTap: _handleShutterPress,
                  child: Container(width: 72, height: 72, decoration: BoxDecoration(shape: BoxShape.circle, color: _isShooting ? Colors.grey : const Color(0xFFCE2029), border: Border.all(color: Colors.white, width: 4)), child: _isShooting ? const Center(child: CircularProgressIndicator(color: Colors.white)) : null),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureIcon(IconData icon, String label, VoidCallback onTap, {bool isActive = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Icon(icon, color: isActive ? Colors.yellowAccent : Colors.white, size: 24), 
        const SizedBox(height: 4), 
        Text(label, style: TextStyle(color: isActive ? Colors.yellowAccent : Colors.white, fontSize: 10))
      ]),
    );
  }

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

  // ✅ [核心] 拍照 + 效果合成 (贴纸在右下角)
  Future<void> _performCapture() async {
    setState(() => _isShooting = true);
    try {
      print("📸 1. 拍摄原始图片...");
      final rawPath = await _cameraService.takePhoto(_currentRatio);
      if (rawPath.isEmpty) { _showErrorDialog("错误", "拍照失败"); return; }

      String finalPath = rawPath;
      
      final stickerPath = _getAssetPath(EditorMockData.stickerCategories, _selectedStickerId);
      final framePath = _getAssetPath(EditorMockData.frameCategories, _selectedFrameId);
      final grainPath = _getAssetPath(EditorMockData.grainCategories, _selectedGrainId);

      bool hasEffects = _selectedFilterId != 'none' || framePath != null || stickerPath != null || grainPath != null;

      if (hasEffects) {
        print("✨ 2. 检测到特效，开始后台合成...");
        
        final effectWidget = Stack(
          fit: StackFit.expand,
          children: [
            Image.file(File(rawPath), fit: BoxFit.cover),
            
            if (_selectedFilterId == 'f_c200') Container(color: Colors.orange.withOpacity(0.1)),
            
            if (grainPath != null) 
               Image.asset(grainPath, fit: BoxFit.cover, color: Colors.white.withOpacity(0.5), colorBlendMode: BlendMode.screen),
            
            if (framePath != null) 
               Image.asset(framePath, fit: BoxFit.fill),
               
            // ✅ [一致性修复] 拍照合成时，贴纸也必须在右下角，与预览一致！
            if (stickerPath != null) 
               Positioned(
                 bottom: 40, // 略微放大一点点像素，适应大图，或者保持 30
                 right: 40,
                 child: Image.asset(stickerPath, width: 150, fit: BoxFit.contain)
               ),
          ],
        );

        final Uint8List imageBytes = await _screenshotController.captureFromWidget(
          Container(
            width: 1080, 
            height: _currentRatio == "1:1" ? 1080 : 1440, 
            child: effectWidget
          ),
          pixelRatio: 2.0, 
          delay: const Duration(milliseconds: 50),
        );

        final directory = await getTemporaryDirectory();
        final fileName = 'recam_baked_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final File processedFile = File('${directory.path}/$fileName');
        await processedFile.writeAsBytes(imageBytes);
        
        finalPath = processedFile.path;
        print("✅ 合成完成: $finalPath");
      }

      await PhotoStorage.savePhoto(finalPath);
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('auto_save_to_gallery') ?? true) {
        await _cameraService.saveToGallery(finalPath);
      }
      
      _runGalleryAnimation();
      
    } catch (e) { 
      print("Capture Error: $e");
      _showErrorDialog("Error", "$e"); 
    } finally { 
      if (mounted) setState(() => _isShooting = false); 
    }
  }

  Widget _buildNewAiBubble(AiRecommendation data) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.yellowAccent)), child: Text("${data.message} (智能推荐)", style: const TextStyle(color: Colors.white)));
  }

  Widget _buildIndependentSlider() {
    return Row(children: [const Icon(Icons.tune, color: Colors.white, size: 16), Expanded(child: Slider(value: _filterIntensity, min: 0, max: 100, activeColor: Colors.yellowAccent, onChanged: (v) => setState(() => _filterIntensity = v)))]);
  }

  void _showErrorDialog(String title, String content) {
    showDialog(context: context, builder: (ctx) => AlertDialog(title: Text(title), content: Text(content), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))]));
  }
}