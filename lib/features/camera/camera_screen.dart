import 'dart:async'; 
import 'dart:io';
import 'dart:typed_data'; // 用于处理图片二进制数据
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart'; // 获取临时路径
import 'package:screenshot/screenshot.dart';       // 截图库
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
  
  // ✅ [新增] 截图控制器，用于后台合成效果
  final ScreenshotController _screenshotController = ScreenshotController();

  bool _isShooting = false;
  String _currentRatio = "4:3"; 
  EditorMode _editorMode = EditorMode.none; 
  
  // ✅ [新增] 状态记录：记住用户在拍照前选了什么
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final viewfinderHeight = screenWidth * (4 / 3);
    final double maskHeight = _currentRatio == "1:1" ? (viewfinderHeight - screenWidth) / 2 : 0.0;

    return Scaffold(
      backgroundColor: Colors.black,
      // 防止键盘或面板顶起导致溢出
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        bottom: false, // 底部区域由 Stack 内部组件自己处理
        child: Stack(
          children: [
            // 1. 主内容 (相机流 + 遮罩 + 顶部栏)
            Column(
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
                      // 遮罩层 (处理 1:1 比例的黑边)
                      Column(
                        children: [
                          AnimatedContainer(duration: const Duration(milliseconds: 300), height: maskHeight, width: double.infinity, color: Colors.black),
                          const Spacer(),
                          AnimatedContainer(duration: const Duration(milliseconds: 300), height: maskHeight, width: double.infinity, color: Colors.black),
                        ],
                      ),
                      
                      // ✅ 实时预览层占位 (这里简单模拟，实际需接 Shader)
                      if (_selectedFilterId == 'f_c200')
                         IgnorePointer(child: Container(color: Colors.orange.withOpacity(0.05))), // 模拟一点暖色
                      if (_selectedGrainId != 'none') 
                        IgnorePointer(child: Container(color: Colors.white.withOpacity(0.05))), // 模拟微弱颗粒

                      // AI 气泡
                      Positioned(
                        bottom: 40 + maskHeight, left: 20, right: 20,
                        child: FadeTransition(
                          opacity: _aiFadeController,
                          child: _currentRecommendation != null ? _buildNewAiBubble(_currentRecommendation!) : const SizedBox(),
                        ),
                      ),
                      
                      // 滑杆 (仅在滤镜模式显示)
                      if (_editorMode == EditorMode.filter)
                        AnimatedPositioned(duration: const Duration(milliseconds: 300), bottom: 10 + maskHeight, left: 20, right: 20, child: _buildIndependentSlider()),
                      
                      // 倒计时数字
                      if (_isCountingDown)
                        Center(child: Text("$_currentCount", style: const TextStyle(color: Colors.white, fontSize: 100, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 10, color: Colors.black)]))),
                    ],
                  ),
                ),
                const Spacer(), // 占位，把下面留给底部面板
              ],
            ),

            // 2. 底部交互区 (固定在最底部)
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: Container(
                color: const Color(0xFF111111),
                // 让子组件决定高度，配合 SafeArea 使用
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

  // --- Components ---

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
    // 如果处于编辑模式，显示二级面板
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
          // ✅ 记录用户选择，用于拍照时合成
          onItemTap: (item) {
            setState(() {
              if (_editorMode == EditorMode.filter) _selectedFilterId = item.id;
              if (_editorMode == EditorMode.frame) _selectedFrameId = item.id;
              if (_editorMode == EditorMode.sticker) _selectedStickerId = item.id;
              if (_editorMode == EditorMode.grain) _selectedGrainId = item.id;
            });
            print("📸 选中效果: ${item.name} (ID: ${item.id})");
          },
        ),
      );
    }
    // 默认显示一级拍照面板
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

  // ✅ [核心逻辑] 拍照 -> 合成 -> 保存
  Future<void> _performCapture() async {
    setState(() => _isShooting = true);
    try {
      print("📸 1. 拍摄原始图片...");
      final rawPath = await _cameraService.takePhoto(_currentRatio);
      if (rawPath.isEmpty) { _showErrorDialog("错误", "拍照失败"); return; }

      String finalPath = rawPath;

      // 检查是否需要合成特效
      bool hasEffects = _selectedFilterId != 'none' || _selectedFrameId != 'none' || 
                        _selectedStickerId != 'none' || _selectedGrainId != 'none';

      if (hasEffects) {
        print("✨ 2. 检测到特效，开始后台合成...");
        
        // 构建不可见的特效层 (逻辑与 Gallery 一致)
        final effectWidget = Stack(
          fit: StackFit.expand,
          children: [
            Image.file(File(rawPath), fit: BoxFit.cover),
            
            // 模拟滤镜 (用 Container 颜色模拟，修复了 blendMode 报错)
            if (_selectedFilterId == 'f_c200') 
              Container(color: Colors.orange.withOpacity(0.1)), 
            
            // 模拟颗粒
            if (_selectedGrainId != 'none') 
              Container(color: Colors.white.withOpacity(0.05)),
              
            // 模拟边框
            if (_selectedFrameId != 'none') 
              Container(decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 20))),
          ],
        );

        // 使用 screenshot 库生成新图
        final Uint8List imageBytes = await _screenshotController.captureFromWidget(
          Container(
            width: 1080, 
            height: _currentRatio == "1:1" ? 1080 : 1440, 
            child: effectWidget
          ),
          pixelRatio: 2.0, 
          delay: const Duration(milliseconds: 50),
        );

        // 写入临时文件
        final directory = await getTemporaryDirectory();
        final fileName = 'recam_baked_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final File processedFile = File('${directory.path}/$fileName');
        await processedFile.writeAsBytes(imageBytes);
        
        finalPath = processedFile.path;
        print("✅ 合成完成: $finalPath");
      }

      // 保存流程
      // 1. 存入 App 内部相册
      await PhotoStorage.savePhoto(finalPath);

      // 2. 根据设置，存入系统相册
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