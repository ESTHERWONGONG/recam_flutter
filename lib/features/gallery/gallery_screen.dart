import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

  // 编辑参数状态
  String? _activeEditToolId; 
  double _brightnessValue = 0.0;
  double _vignetteValue = 0.0;
  bool _isMirrored = false;

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

  void _resetEditorState() {
    _editorMode = EditorMode.none;
    _activeEditToolId = null;
    _brightnessValue = 0.0;
    _vignetteValue = 0.0;
    _isMirrored = false;
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
        // ✅ 关键：防止键盘或面板顶起页面导致溢出
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

  // ✅ [修复布局] 移除外层 SafeArea，改为内部精细控制
  Widget _buildImmersivePreview() {
    if (_photos.isEmpty) return const SizedBox();

    return Stack(
      fit: StackFit.expand, // 👈 关键：占满全屏
      children: [
        Column(
          children: [
            // 1. 顶部栏：只保护顶部刘海
            SafeArea(
              bottom: false,
              child: _buildCustomTopBar(),
            ),
            
            // 2. 图片区域：占据中间所有剩余空间
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _photos.length,
                physics: _editorMode == EditorMode.none 
                    ? const BouncingScrollPhysics() 
                    : const NeverScrollableScrollPhysics(),
                onPageChanged: (index) => setState(() => _currentIndex = index),
                itemBuilder: (context, index) {
                  return _ZoomablePhoto(
                    file: File(_photos[index].path),
                    enableZoom: _editorMode == EditorMode.none,
                    brightness: _brightnessValue,
                    vignette: _vignetteValue,
                    isMirrored: _isMirrored,
                  );
                },
              ),
            ),
            
            // 3. 底部切换区域 (一级菜单 OR 二级面板)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(animation),
                  child: child,
                );
              },
              child: _editorMode == EditorMode.none
                  ? _buildBottomEditorBar() 
                  : _buildSpecificPanel(), 
            ),
          ],
        ),

        // 4. 浮动滑杆 (仅在需要调节数值时显示)
        if (_editorMode == EditorMode.edit && (_activeEditToolId == 'brightness' || _activeEditToolId == 'vignette'))
          Positioned(
            bottom: 220, // 位于面板上方，避开手指遮挡
            left: 40, right: 40,
            child: _buildValueSlider(),
          ),
      ],
    );
  }

  Widget _buildValueSlider() {
    double value = 0.0;
    double min = 0.0;
    double max = 1.0;
    String label = "";

    if (_activeEditToolId == 'brightness') {
      value = _brightnessValue;
      min = -0.5; max = 0.5; label = "亮度";
    } else if (_activeEditToolId == 'vignette') {
      value = _vignetteValue;
      min = 0.0; max = 0.8; label = "暗角";
    }

    return Column(
      children: [
        Text("$label: ${(value * 100).toInt()}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 4)])),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: SliderComponentShape.noOverlay,
            activeTrackColor: Colors.yellowAccent,
            inactiveTrackColor: Colors.white30,
            thumbColor: Colors.white,
          ),
          child: Slider(
            value: value, min: min, max: max,
            onChanged: (v) {
              setState(() {
                if (_activeEditToolId == 'brightness') _brightnessValue = v;
                if (_activeEditToolId == 'vignette') _vignetteValue = v;
              });
            },
          ),
        ),
      ],
    );
  }

  // ✅ [UI优化] 一级菜单：保持高度占位，内容垂直居中
  Widget _buildBottomEditorBar() {
    return Container(
      key: const ValueKey('BottomIcons'),
      color: Colors.black,
      child: SafeArea(
        top: false,
        child: Container(
          // 必须保持这个高度，与二级面板(UnifiedEditorPanel)高度一致，防止跳动
          height: 200, 
          // ✅ 让图标在 200px 的空间里垂直居中
          alignment: Alignment.center, 
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
    List<EditorCategory> categories = [];
    Key panelKey = const ValueKey('EmptyPanel');

    switch (_editorMode) {
      case EditorMode.filter: categories = EditorMockData.filterCategories; panelKey = const ValueKey('FilterPanel'); break;
      case EditorMode.frame: categories = EditorMockData.frameCategories; panelKey = const ValueKey('FramePanel'); break;
      case EditorMode.sticker: categories = EditorMockData.stickerCategories; panelKey = const ValueKey('StickerPanel'); break;
      case EditorMode.grain: categories = EditorMockData.grainCategories; panelKey = const ValueKey('GrainPanel'); break;
      case EditorMode.edit: categories = EditorMockData.editCategories; panelKey = const ValueKey('EditPanel'); break;
      default: return const SizedBox();
    }

    return Container(
      key: panelKey,
      color: const Color(0xFF111111),
      child: SafeArea(
        top: false,
        child: UnifiedEditorPanel(
          categories: categories,
          onClose: () => setState(() {
            _editorMode = EditorMode.none;
            _activeEditToolId = null; 
          }),
          onItemTap: (item) {
            setState(() {
              _activeEditToolId = item.id;
              // 镜像翻转直接生效，不需要滑杆
              if (item.id == 'mirror') {
                _isMirrored = !_isMirrored;
              }
            });
          },
        ),
      ),
    );
  }

  Widget _buildCustomTopBar() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: Colors.black,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
            onPressed: () {
              if (_editorMode != EditorMode.none) {
                setState(() { _editorMode = EditorMode.none; _activeEditToolId = null; });
              } else {
                _exitPreviewMode();
              }
            },
          ),
          if (_currentIndex != null && _editorMode == EditorMode.none)
            Text(DateFormat('yyyy/MM/dd HH:mm').format(_photos[_currentIndex!].createdAt), style: const TextStyle(color: Colors.white54, fontSize: 12, fontFamily: "Menlo")),
          
          Row(
            children: [
              if (_editorMode == EditorMode.none)
                IconButton(icon: const Icon(Icons.delete_outline, color: Colors.white, size: 24), onPressed: _deleteCurrentPhoto),
              if (_editorMode == EditorMode.none)
                IconButton(icon: const Icon(Icons.download_rounded, color: Colors.yellowAccent, size: 24), onPressed: () => _saveToSystemAlbum(context, _photos[_currentIndex!].path)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildEditorIcon(IconData icon, String label, EditorMode mode) {
    return GestureDetector(
      onTap: () => setState(() => _editorMode = mode),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(padding: const EdgeInsets.all(10), decoration: const BoxDecoration(shape: BoxShape.circle), child: Icon(icon, color: Colors.white, size: 26)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildGridView() {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Colors.yellowAccent));
    if (_photos.isEmpty) return const Center(child: Text("还没有照片", style: TextStyle(color: Colors.grey)));

    return GridView.builder(
      padding: const EdgeInsets.all(1),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, crossAxisSpacing: 1.5, mainAxisSpacing: 1.5, childAspectRatio: 0.66,
      ),
      itemCount: _photos.length,
      itemBuilder: (context, index) {
        final photo = _photos[index];
        return GestureDetector(
          onTap: () => _enterPreviewMode(index),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(File(photo.path), fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey[900])),
              Positioned(bottom: 0, left: 0, right: 0, child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withOpacity(0.6), Colors.transparent])), child: Text(DateFormat('MM-dd').format(photo.createdAt), style: const TextStyle(color: Colors.white, fontSize: 10), textAlign: TextAlign.right))),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveToSystemAlbum(BuildContext context, String path) async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('正在保存...'), duration: Duration(milliseconds: 500)));
    final success = await NativeCameraService().saveToGallery(path);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success ? '✅ 已保存到系统相册' : '❌ 保存失败'), backgroundColor: success ? Colors.green : Colors.red));
    }
  }
}

// -----------------------------------------------------------
// ✅ [升级版组件] 支持缩放 + 实时编辑 (亮度/镜像/暗角)
// -----------------------------------------------------------
class _ZoomablePhoto extends StatefulWidget {
  final File file;
  final bool enableZoom;
  final double brightness;
  final double vignette;
  final bool isMirrored;

  const _ZoomablePhoto({
    required this.file, 
    required this.enableZoom,
    this.brightness = 0.0,
    this.vignette = 0.0,
    this.isMirrored = false,
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
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 200))..addListener(() { _transformationController.value = _animation!.value; });
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    if (!widget.enableZoom) return;
    Matrix4 endMatrix;
    Offset position = _doubleTapDetails != null ? _doubleTapDetails!.localPosition : Offset.zero;
    if (_transformationController.value != Matrix4.identity()) {
      endMatrix = Matrix4.identity();
    } else {
      endMatrix = Matrix4.identity()..translate(-position.dx, -position.dy)..scale(2.0)..translate(position.dx / 2, position.dy / 2);
    }
    _animation = Matrix4Tween(begin: _transformationController.value, end: endMatrix).animate(CurveTween(curve: Curves.easeInOut).animate(_animationController));
    _animationController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: (d) => _doubleTapDetails = d,
      onDoubleTap: _handleDoubleTap,
      child: Center(
        child: InteractiveViewer(
          transformationController: _transformationController,
          minScale: 1.0, maxScale: 3.0,
          scaleEnabled: widget.enableZoom,
          child: _buildEditedImage(),
        ),
      ),
    );
  }

  Widget _buildEditedImage() {
    return Transform(
      alignment: Alignment.center,
      transform: widget.isMirrored ? Matrix4.rotationY(math.pi) : Matrix4.identity(),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColorFiltered(
            colorFilter: ColorFilter.matrix([
              1, 0, 0, 0, widget.brightness * 255, 
              0, 1, 0, 0, widget.brightness * 255, 
              0, 0, 1, 0, widget.brightness * 255, 
              0, 0, 0, 1, 0,
            ]),
            child: Image.file(widget.file, fit: BoxFit.contain),
          ),
          if (widget.vignette > 0)
            IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [Colors.transparent, Colors.black.withOpacity(widget.vignette)],
                    radius: 1.5 - widget.vignette, 
                    center: Alignment.center,
                    stops: const [0.4, 1.0], 
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}