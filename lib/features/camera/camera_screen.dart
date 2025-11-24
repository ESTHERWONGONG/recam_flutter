import 'dart:async'; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool _isShooting = false;
  String _currentRatio = "4:3"; 
  EditorMode _editorMode = EditorMode.none; 
  double _filterIntensity = 80.0;

  // ✅ [新增] 定时器状态 (0, 3, 7)
  int _timerDuration = 0;
  // ✅ [新增] 是否正在倒计时中
  bool _isCountingDown = false;
  // ✅ [新增] 当前倒计时数字 (用于UI显示)
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

    _aiFadeController = AnimationController(
      vsync: this, 
      duration: const Duration(seconds: 2), 
      value: 0.0, 
    );

    _cameraService.aiStream.listen((data) async {
      // ✅ [修改] 每次收到数据，先检查用户是否开启了 AI
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
        if (mounted) {
          _aiFadeController.reverse();
        }
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
    final double maskHeight = _currentRatio == "1:1" 
        ? (viewfinderHeight - screenWidth) / 2 
        : 0.0;

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
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: maskHeight, width: double.infinity, color: Colors.black,
                      ),
                      const Spacer(),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: maskHeight, width: double.infinity, color: Colors.black,
                      ),
                    ],
                  ),

                  // AI 气泡
                  Positioned(
                    bottom: 40 + maskHeight, 
                    left: 20,
                    right: 20,
                    child: FadeTransition(
                      opacity: _aiFadeController,
                      child: _currentRecommendation != null 
                          ? _buildNewAiBubble(_currentRecommendation!) 
                          : const SizedBox(),
                    ),
                  ),

                  // 独立滑杆
                  if (_editorMode == EditorMode.filter)
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 300),
                      bottom: 10 + maskHeight, 
                      left: 20, right: 20,
                      child: _buildIndependentSlider(),
                    ),

                  // ✅ [新增] 倒计时大数字动画
                  if (_isCountingDown)
                    Center(
                      child: Text(
                        "$_currentCount",
                        style: const TextStyle(
                          color: Colors.white, 
                          fontSize: 100, 
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(blurRadius: 10, color: Colors.black)],
                        ),
                      ),
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
                    AnimatedSwitcher(
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

  // --- 顶部栏 (含新增定时器) ---
  Widget _buildTopBar() {
    if (_editorMode != EditorMode.none) return const SizedBox(height: 50);
    
    return Container(
      height: 50, color: Colors.black,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white), 
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
          
          // ✅ [新增] 定时器按钮
          // 逻辑：点击循环 0s -> 3s -> 7s -> 0s
          GestureDetector(
            onTap: () {
              setState(() {
                if (_timerDuration == 0) _timerDuration = 3;
                else if (_timerDuration == 3) _timerDuration = 7;
                else _timerDuration = 0;
              });
            },
            child: Container(
              width: 24, 
              alignment: Alignment.center,
              child: _timerDuration == 0
                  ? const Icon(Icons.timer_off, color: Colors.white) // 关
                  : Text("${_timerDuration}s", style: const TextStyle(color: Colors.yellowAccent, fontWeight: FontWeight.bold)), // 开
            ),
          ),

          // 闪光灯
          IconButton(icon: Icon(_flashMode == 'on' ? Icons.flash_on : Icons.flash_off, color: Colors.white), onPressed: () {
             final newMode = _flashMode == 'off' ? 'auto' : (_flashMode == 'auto' ? 'on' : 'off');
             setState(() => _flashMode = newMode);
             _cameraService.setFlashMode(newMode);
          }),
          
          // 比例
          TextButton(onPressed: () => setState(() => _currentRatio = (_currentRatio == "4:3") ? "1:1" : "4:3"), 
            child: Text(_currentRatio, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          
          // 翻转
          IconButton(icon: const Icon(Icons.flip_camera_ios, color: Colors.white), onPressed: () => _cameraService.switchCamera()),
        ],
      ),
    );
  }

  // --- 拍照逻辑 (含倒计时) ---
  Future<void> _handleShutterPress() async {
    if (_isShooting || _isCountingDown) return; // 如果正在倒计时或正在拍，不响应

    // 1. 检查是否有定时器
    if (_timerDuration > 0) {
      setState(() {
        _isCountingDown = true;
        _currentCount = _timerDuration;
      });

      // 启动倒计时
      Timer.periodic(const Duration(seconds: 1), (timer) async {
        if (_currentCount > 1) {
          setState(() => _currentCount--);
        } else {
          // 倒计时结束
          timer.cancel();
          setState(() => _isCountingDown = false); // 隐藏数字
          await _performCapture(); // 执行拍照
        }
      });
    } else {
      // 无定时，直接拍
      await _performCapture();
    }
  }

  // 真正的拍照动作 (抽离出来)
  Future<void> _performCapture() async {
    setState(() => _isShooting = true);
    try {
      print("📸 1. 开始拍照...");
      final path = await _cameraService.takePhoto(_currentRatio);
      
      if (path.isEmpty) { 
        _showErrorDialog("存储空间已满", "无法写入临时文件。"); 
        return; 
      }
      
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('auto_save_to_gallery') ?? true) await _cameraService.saveToGallery(path);
      await PhotoStorage.savePhoto(path);
      _runGalleryAnimation();
      
    } catch (e) { 
      _showErrorDialog("未知错误", "Error: $e"); 
    } finally { 
      if (mounted) setState(() => _isShooting = false); 
    }
  }

  // ... (以下 UI 组件保持不变) ...

  Widget _buildNewAiBubble(AiRecommendation data) {
    final List<String> tags = ["暖色", "人像"]; 
    final String mockFilterName = "✨Fuji-033"; 

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6), 
        borderRadius: BorderRadius.circular(30), 
        border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.8), width: 1.5), 
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${data.message}，适合 $mockFilterName", 
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: tags.map((tag) => Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.yellowAccent.withOpacity(0.5)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(tag, style: const TextStyle(color: Colors.yellowAccent, fontSize: 10)),
                  )).toList(),
                )
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () {
              _aiFadeController.reverse();
              print("用户接受了推荐: ${data.filmId}");
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFD4A017), 
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text("确定", style: TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildIndependentSlider() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.tune, color: Colors.white70, size: 16), 
        const SizedBox(width: 8),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2, 
              activeTrackColor: Colors.yellowAccent,
              inactiveTrackColor: Colors.white30,
              thumbColor: Colors.white,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6, elevation: 2),
              overlayShape: SliderComponentShape.noOverlay,
            ),
            child: Slider(
              value: _filterIntensity,
              min: 0, max: 100,
              onChanged: (v) => setState(() => _filterIntensity = v),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _filterIntensity.toInt().toString(), 
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildBottomPanelContent() {
    switch (_editorMode) {
      case EditorMode.filter:
        return UnifiedEditorPanel(
          key: const ValueKey('FilterPanel'),
          categories: EditorMockData.filterCategories,
          onClose: () => setState(() => _editorMode = EditorMode.none),
        );
      case EditorMode.frame:
        return UnifiedEditorPanel(
          key: const ValueKey('FramePanel'),
          categories: EditorMockData.frameCategories,
          onClose: () => setState(() => _editorMode = EditorMode.none),
        );
      case EditorMode.sticker:
        return UnifiedEditorPanel(
          key: const ValueKey('StickerPanel'),
          categories: EditorMockData.frameCategories, 
          onClose: () => setState(() => _editorMode = EditorMode.none),
        );
      case EditorMode.none:
      default:
        return _buildCapturePanel();
    }
  }

  Widget _buildCapturePanel() {
    return Container(
      key: const ValueKey('CapturePanel'),
      padding: const EdgeInsets.only(bottom: 20, top: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildFeatureIcon(Icons.crop_free, "边框", () => setState(() => _editorMode = EditorMode.frame)),
              _buildFeatureIcon(Icons.face, "贴纸", () => setState(() => _editorMode = EditorMode.sticker)),
              _buildFeatureIcon(Icons.color_lens, "滤镜", () => setState(() => _editorMode = EditorMode.filter)),
            ],
          ),
          const SizedBox(height: 20),
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
              const SizedBox(width: 40),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureIcon(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [Icon(icon, color: Colors.white, size: 24), const SizedBox(height: 4), Text(label, style: const TextStyle(color: Colors.white, fontSize: 10))]),
    );
  }

  Widget _buildZoomBtn(double zoom) {
    return GestureDetector(
      onTap: () => _cameraService.setZoom(zoom),
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withOpacity(0.5), border: Border.all(color: Colors.white, width: 1.5)),
        alignment: Alignment.center,
        child: Text("${zoom}x", style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _showErrorDialog(String title, String content) {
    showDialog(context: context, barrierDismissible: false, builder: (context) => AlertDialog(title: Text(title, style: const TextStyle(color: Colors.red)), content: Text(content), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("知道了"))]));
  }
}