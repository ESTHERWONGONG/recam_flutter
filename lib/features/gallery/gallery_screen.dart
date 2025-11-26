import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import '../../services/native_camera_service.dart';
import '../../data/photo_storage.dart';
import '../editor/widgets/unified_editor_panel.dart';
import '../editor/editor_constants.dart'; 

class GalleryScreen extends StatefulWidget {
  static const route = '/gallery';
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  int? _currentIndex; 
  List<ReCamPhoto> _photos = [];
  bool _isLoading = true;
  PageController? _pageController;
  EditorMode _editorMode = EditorMode.none;

  final ScreenshotController _screenshotController = ScreenshotController();

  // ✅ [新增] 完整的编辑状态 (不再只有亮度)
  String? _activeEditToolId; 
  double _brightnessValue = 0.0;
  double _vignetteValue = 0.0;
  bool _isMirrored = false;
  
  // ✅ [新增] 记录选中的素材 ID
  String _selectedFilterId = 'none';
  String _selectedFrameId = 'none';
  String _selectedStickerId = 'none';
  String _selectedGrainId = 'none';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isLoading) _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    final list = await PhotoStorage.getAllPhotos();
    if (mounted) {
      setState(() {
        _photos = list;
        _isLoading = false;
        final args = ModalRoute.of(context)?.settings.arguments;
        if (args is String && _photos.isNotEmpty) {
          final index = _photos.indexWhere((p) => p.path == args);
          if (index != -1) _enterPreviewMode(index);
          else _enterPreviewMode(0);
        }
      });
    }
  }

  void _enterPreviewMode(int index) {
    setState(() {
      _currentIndex = index;
      _pageController = PageController(initialPage: index);
      _resetEditorState();
    });
  }

  void _exitPreviewMode() {
    setState(() {
      _currentIndex = null;
      _pageController?.dispose();
      _pageController = null;
      _resetEditorState();
    });
  }

  // ✅ 重置所有状态
  void _resetEditorState() {
    _editorMode = EditorMode.none;
    _activeEditToolId = null;
    _brightnessValue = 0.0;
    _vignetteValue = 0.0;
    _isMirrored = false;
    _selectedFilterId = 'none';
    _selectedFrameId = 'none';
    _selectedStickerId = 'none';
    _selectedGrainId = 'none';
  }

  Future<void> _saveEditedPhoto() async {
    if (_currentIndex == null) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('正在生成大片...'), duration: Duration(seconds: 1)));

    try {
      // 截图当前的渲染结果 (所见即所得)
      final Uint8List? imageBytes = await _screenshotController.capture(pixelRatio: 3.0);

      if (imageBytes != null) {
        final directory = await getTemporaryDirectory();
        final fileName = 'recam_edit_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final File tempFile = File('${directory.path}/$fileName');
        await tempFile.writeAsBytes(imageBytes);

        final success = await NativeCameraService().saveToGallery(tempFile.path);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(success ? '✅ 已保存到系统相册' : '❌ 保存失败'),
            backgroundColor: success ? Colors.green : Colors.red,
          ));
        }
      }
    } catch (e) {
      print("Save Edit Error: $e");
    }
  }

  Future<void> _deleteCurrentPhoto() async {
    if (_currentIndex == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF222222),
        title: const Text("删除照片", style: TextStyle(color: Colors.white)),
        content: const Text("确定要删除这张照片吗？", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("取消", style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("删除", style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _photos.removeAt(_currentIndex!);
        if (_photos.isEmpty) {
          _exitPreviewMode();
        } else if (_currentIndex! >= _photos.length) {
          _currentIndex = _photos.length - 1;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isPreviewMode = _currentIndex != null;
    if (isPreviewMode) {
      return Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: _buildImmersivePreview(),
      );
    }
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Gallery', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _buildGridView(),
    );
  }

  Widget _buildImmersivePreview() {
    if (_photos.isEmpty) return const SizedBox();

    return Stack(
      fit: StackFit.expand,
      children: [
        Column(
          children: [
            SafeArea(bottom: false, child: _buildCustomTopBar()),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _photos.length,
                physics: _editorMode == EditorMode.none ? const BouncingScrollPhysics() : const NeverScrollableScrollPhysics(),
                onPageChanged: (index) => setState(() => _currentIndex = index),
                itemBuilder: (context, index) {
                  // ✅ 传入所有选中的 ID
                  return _ZoomablePhoto(
                    file: File(_photos[index].path),
                    screenshotController: index == _currentIndex ? _screenshotController : null,
                    enableZoom: _editorMode == EditorMode.none,
                    
                    // 编辑参数
                    brightness: _brightnessValue,
                    vignette: _vignetteValue,
                    isMirrored: _isMirrored,
                    
                    // 素材 ID
                    filterId: _selectedFilterId,
                    frameId: _selectedFrameId,
                    stickerId: _selectedStickerId,
                    grainId: _selectedGrainId,
                  );
                },
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (Widget child, Animation<double> animation) => SlideTransition(position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(animation), child: child),
              child: _editorMode == EditorMode.none ? _buildBottomEditorBar() : _buildSpecificPanel(), 
            ),
          ],
        ),
        if (_editorMode == EditorMode.edit && (_activeEditToolId == 'brightness' || _activeEditToolId == 'vignette'))
          Positioned(bottom: 220, left: 40, right: 40, child: _buildValueSlider()),
      ],
    );
  }

  Widget _buildValueSlider() {
    double value = 0.0; double min = 0.0; double max = 1.0; String label = "";
    if (_activeEditToolId == 'brightness') { value = _brightnessValue; min = -0.5; max = 0.5; label = "亮度"; } 
    else if (_activeEditToolId == 'vignette') { value = _vignetteValue; min = 0.0; max = 0.8; label = "暗角"; }
    return Column(children: [Text("$label: ${(value * 100).toInt()}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 4)])), SliderTheme(data: SliderTheme.of(context).copyWith(trackHeight: 2, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8), overlayShape: SliderComponentShape.noOverlay, activeTrackColor: Colors.yellowAccent, inactiveTrackColor: Colors.white30, thumbColor: Colors.white), child: Slider(value: value, min: min, max: max, onChanged: (v) => setState(() { if (_activeEditToolId == 'brightness') _brightnessValue = v; if (_activeEditToolId == 'vignette') _vignetteValue = v; })))]);
  }

  Widget _buildBottomEditorBar() {
    return Container(
      key: const ValueKey('BottomIcons'),
      color: Colors.black,
      child: SafeArea(
        top: false,
        child: Container(
          height: 200, alignment: Alignment.center, 
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildEditorIcon(Icons.color_lens_outlined, "滤镜", EditorMode.filter),
              _buildEditorIcon(Icons.tune, "编辑", EditorMode.edit),
              _buildEditorIcon(Icons.face_retouching_natural, "贴纸", EditorMode.sticker),
              _buildEditorIcon(Icons.grain, "颗粒", EditorMode.grain),
              _buildEditorIcon(Icons.crop_free, "边框", EditorMode.frame),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpecificPanel() {
    List<EditorCategory> categories = []; Key panelKey = const ValueKey('EmptyPanel');
    switch (_editorMode) { 
      case EditorMode.filter: categories = EditorMockData.filterCategories; panelKey = const ValueKey('FilterPanel'); break; 
      case EditorMode.frame: categories = EditorMockData.frameCategories; panelKey = const ValueKey('FramePanel'); break; 
      case EditorMode.sticker: categories = EditorMockData.stickerCategories; panelKey = const ValueKey('StickerPanel'); break; 
      case EditorMode.grain: categories = EditorMockData.grainCategories; panelKey = const ValueKey('GrainPanel'); break; 
      case EditorMode.edit: categories = EditorMockData.editCategories; panelKey = const ValueKey('EditPanel'); break; 
      default: return const SizedBox(); 
    }
    return Container(
      key: panelKey, color: const Color(0xFF111111),
      child: SafeArea(
        top: false,
        child: UnifiedEditorPanel(
          categories: categories,
          onClose: () => setState(() { _editorMode = EditorMode.none; _activeEditToolId = null; }),
          
          // ✅ [更新] 更新选中状态
          onItemTap: (item) {
            setState(() {
              if (_editorMode == EditorMode.filter) _selectedFilterId = item.id;
              if (_editorMode == EditorMode.frame) _selectedFrameId = item.id;
              if (_editorMode == EditorMode.sticker) _selectedStickerId = item.id;
              if (_editorMode == EditorMode.grain) _selectedGrainId = item.id;
              
              // 编辑模式特殊处理
              if (_editorMode == EditorMode.edit) {
                _activeEditToolId = item.id;
                if (item.id == 'mirror') _isMirrored = !_isMirrored;
              }
            });
          },
        ),
      ),
    );
  }

  Widget _buildCustomTopBar() {
    return Container(
      height: 44, padding: const EdgeInsets.symmetric(horizontal: 8), color: Colors.black,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20), onPressed: () { if (_editorMode != EditorMode.none) { setState(() { _editorMode = EditorMode.none; _activeEditToolId = null; }); } else { _exitPreviewMode(); } }),
          if (_currentIndex != null && _editorMode == EditorMode.none) Text(DateFormat('yyyy/MM/dd HH:mm').format(_photos[_currentIndex!].createdAt), style: const TextStyle(color: Colors.white54, fontSize: 12, fontFamily: "Menlo")),
          Row(children: [ if (_editorMode == EditorMode.none) IconButton(icon: const Icon(Icons.delete_outline, color: Colors.white, size: 24), onPressed: _deleteCurrentPhoto), if (_editorMode == EditorMode.none) IconButton(icon: const Icon(Icons.download_rounded, color: Colors.yellowAccent, size: 24), onPressed: _saveEditedPhoto) ]),
        ],
      ),
    );
  }

  Widget _buildEditorIcon(IconData icon, String label, EditorMode mode) {
    return GestureDetector(onTap: () => setState(() => _editorMode = mode), child: Column(mainAxisSize: MainAxisSize.min, children: [Container(padding: const EdgeInsets.all(10), decoration: const BoxDecoration(shape: BoxShape.circle), child: Icon(icon, color: Colors.white, size: 26)), const SizedBox(height: 4), Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10))]));
  }

  Widget _buildGridView() {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Colors.yellowAccent));
    if (_photos.isEmpty) return const Center(child: Text("还没有照片", style: TextStyle(color: Colors.grey)));
    return GridView.builder(padding: const EdgeInsets.all(1), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 1.5, mainAxisSpacing: 1.5, childAspectRatio: 0.66), itemCount: _photos.length, itemBuilder: (context, index) { final photo = _photos[index]; return GestureDetector(onTap: () => _enterPreviewMode(index), child: Stack(fit: StackFit.expand, children: [ Image.file(File(photo.path), fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey[900])), Positioned(bottom: 0, left: 0, right: 0, child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withOpacity(0.6), Colors.transparent])), child: Text(DateFormat('MM-dd').format(photo.createdAt), style: const TextStyle(color: Colors.white, fontSize: 10), textAlign: TextAlign.right))) ])); });
  }
}

// -----------------------------------------------------------
// ✅ 升级版图片组件：支持素材叠加
// -----------------------------------------------------------
class _ZoomablePhoto extends StatefulWidget {
  final File file;
  final bool enableZoom;
  final ScreenshotController? screenshotController; 
  
  // 编辑数值
  final double brightness;
  final double vignette;
  final bool isMirrored;
  
  // 素材 ID
  final String filterId;
  final String frameId;
  final String stickerId;
  final String grainId;

  const _ZoomablePhoto({
    required this.file, 
    required this.enableZoom,
    this.screenshotController, 
    this.brightness = 0.0,
    this.vignette = 0.0,
    this.isMirrored = false,
    this.filterId = 'none',
    this.frameId = 'none',
    this.stickerId = 'none',
    this.grainId = 'none',
  });

  @override
  State<_ZoomablePhoto> createState() => _ZoomablePhotoState();
}

class _ZoomablePhotoState extends State<_ZoomablePhoto> with SingleTickerProviderStateMixin {
  final TransformationController _transformationController = TransformationController();
  TapDownDetails? _doubleTapDetails;
  late AnimationController _animationController;
  Animation<Matrix4>? _animation;

  @override
  void initState() { super.initState(); _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 200))..addListener(() { _transformationController.value = _animation!.value; }); }
  @override
  void dispose() { _transformationController.dispose(); _animationController.dispose(); super.dispose(); }
  void _handleDoubleTap() { if (!widget.enableZoom) return; Matrix4 endMatrix; Offset position = _doubleTapDetails != null ? _doubleTapDetails!.localPosition : Offset.zero; if (_transformationController.value != Matrix4.identity()) { endMatrix = Matrix4.identity(); } else { endMatrix = Matrix4.identity()..translate(-position.dx, -position.dy)..scale(2.0)..translate(position.dx / 2, position.dy / 2); } _animation = Matrix4Tween(begin: _transformationController.value, end: endMatrix).animate(CurveTween(curve: Curves.easeInOut).animate(_animationController)); _animationController.forward(from: 0); }
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(onDoubleTapDown: (d) => _doubleTapDetails = d, onDoubleTap: _handleDoubleTap, child: Center(child: InteractiveViewer(transformationController: _transformationController, minScale: 1.0, maxScale: 3.0, scaleEnabled: widget.enableZoom, child: _buildContentWithScreenshot())));
  }

  Widget _buildContentWithScreenshot() {
    final content = _buildEditedImage();
    if (widget.screenshotController != null) { return Screenshot(controller: widget.screenshotController!, child: content); }
    return content;
  }

  // ✅ [Helper] 查找资源路径
  String? _getAssetPath(List<EditorCategory> categories, String id) {
    if (id == 'none') return null;
    for (var cat in categories) {
      for (var item in cat.items) {
        if (item.id == id) return item.assetPath;
      }
    }
    return null;
  }

  Widget _buildEditedImage() {
    // 获取资源路径
    final framePath = _getAssetPath(EditorMockData.frameCategories, widget.frameId);
    final grainPath = _getAssetPath(EditorMockData.grainCategories, widget.grainId);
    final stickerPath = _getAssetPath(EditorMockData.stickerCategories, widget.stickerId);

    return Transform(
      alignment: Alignment.center,
      transform: widget.isMirrored ? Matrix4.rotationY(math.pi) : Matrix4.identity(),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. 底图 (亮度 + 滤镜颜色模拟)
          ColorFiltered(
            colorFilter: ColorFilter.matrix([
              1, 0, 0, 0, widget.brightness * 255, 
              0, 1, 0, 0, widget.brightness * 255, 
              0, 0, 1, 0, widget.brightness * 255, 
              0, 0, 0, 1, 0,
            ]),
            // 如果有滤镜ID，这里可以加更多逻辑，暂时先不动
            child: Image.file(widget.file, fit: BoxFit.contain),
          ),

          // 2. 颗粒/光效 (叠加模式)
          // ✅ 如果找到了路径，且文件存在，就渲染
          if (grainPath != null && grainPath.isNotEmpty)
            Image.asset(
              grainPath,
              fit: BoxFit.cover,
              // 滤色模式 (去黑留白)，非常适合漏光素材
              color: Colors.white.withOpacity(0.8), 
              colorBlendMode: BlendMode.screen,
              errorBuilder: (c,e,s) => const SizedBox(), // 没图时不崩
            ),

          // 3. 暗角
          if (widget.vignette > 0)
            IgnorePointer(child: Container(decoration: BoxDecoration(gradient: RadialGradient(colors: [Colors.transparent, Colors.black.withOpacity(widget.vignette)], radius: 1.5 - widget.vignette, center: Alignment.center, stops: const [0.4, 1.0])))),

          // 4. 边框 (Frame)
          // ✅ 覆盖在最上层
          if (framePath != null && framePath.isNotEmpty)
            Image.asset(
              framePath,
              fit: BoxFit.fill, // 边框通常需要拉伸填满
              errorBuilder: (c,e,s) => Container(decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 10))), // 没图时显示白框兜底
            ),

          // 5. 贴纸 (Sticker)
          // ✅ 居中显示 (未来做成可拖拽)
          if (stickerPath != null && stickerPath.isNotEmpty)
            Center(
              child: Image.asset(
                stickerPath,
                width: 150, // 默认大小
                fit: BoxFit.contain,
                errorBuilder: (c,e,s) => const Icon(Icons.emoji_emotions, size: 100, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}