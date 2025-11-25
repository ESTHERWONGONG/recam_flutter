import 'dart:io';
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
      _editorMode = EditorMode.none;
    });
  }

  void _exitPreviewMode() {
    setState(() {
      _currentIndex = null;
      _pageController?.dispose();
      _pageController = null;
      _editorMode = EditorMode.none;
    });
  }

  // ✅ [新增] 删除照片逻辑
  Future<void> _deleteCurrentPhoto() async {
    if (_currentIndex == null) return;
    
    // 弹窗确认
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF222222),
        title: const Text("删除照片", style: TextStyle(color: Colors.white)),
        content: const Text("确定要删除这张照片吗？此操作无法撤销。", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("取消", style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("删除", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final photo = _photos[_currentIndex!];
      // 1. 本地文件删除 (逻辑需在 PhotoStorage 实现，这里暂演示从列表移除)
      // await PhotoStorage.delete(photo.path); // 你需要在 PhotoStorage 加这个方法
      // 暂时只从 UI 移除:
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

    return SafeArea(
      child: Column(
        children: [
          _buildCustomTopBar(),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _photos.length,
              physics: _editorMode == EditorMode.none 
                  ? const BouncingScrollPhysics() 
                  : const NeverScrollableScrollPhysics(),
              onPageChanged: (index) => setState(() => _currentIndex = index),
              itemBuilder: (context, index) {
                // ✅ [优化] 使用封装好的缩放组件
                return _ZoomablePhoto(
                  file: File(_photos[index].path),
                  enableZoom: _editorMode == EditorMode.none,
                );
              },
            ),
          ),
          
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
    );
  }

  // --- 自定义顶部栏 (增加了删除按钮) ---
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
                setState(() => _editorMode = EditorMode.none);
              } else {
                _exitPreviewMode();
              }
            },
          ),
          if (_currentIndex != null && _editorMode == EditorMode.none)
            Text(
              DateFormat('yyyy/MM/dd HH:mm').format(_photos[_currentIndex!].createdAt),
              style: const TextStyle(color: Colors.white54, fontSize: 12, fontFamily: "Menlo"),
            ),
          
          Row(
            children: [
               // ✅ [新增] 删除按钮
              if (_editorMode == EditorMode.none)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.white, size: 24),
                  onPressed: _deleteCurrentPhoto,
                ),
              if (_editorMode == EditorMode.none)
                IconButton(
                  icon: const Icon(Icons.download_rounded, color: Colors.yellowAccent, size: 24),
                  onPressed: () => _saveToSystemAlbum(context, _photos[_currentIndex!].path),
                ),
            ],
          )
        ],
      ),
    );
  }

  // ... (buildBottomEditorBar, buildSpecificPanel, buildEditorIcon 保持不变，为了节省篇幅我省略了，请保持你原有的逻辑，或者需要我完整贴出来请告诉我) ...
  // 为了确保你复制不出错，这里还是完整贴出底部逻辑
  
  Widget _buildBottomEditorBar() {
    return Container(
      key: const ValueKey('BottomIcons'),
      height: 100,
      padding: const EdgeInsets.only(bottom: 20, top: 10),
      color: Colors.black,
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
      child: UnifiedEditorPanel(
        categories: categories,
        onClose: () => setState(() => _editorMode = EditorMode.none),
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
// ✅ [新组件] 专门处理图片缩放 (支持双指捏合 + 双击放大)
// -----------------------------------------------------------
class _ZoomablePhoto extends StatefulWidget {
  final File file;
  final bool enableZoom;

  const _ZoomablePhoto({required this.file, required this.enableZoom});

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
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..addListener(() {
        _transformationController.value = _animation!.value;
      });
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // 双击事件：如果已放大则还原，否则放大到 2 倍
  void _handleDoubleTap() {
    if (!widget.enableZoom) return;

    Matrix4 endMatrix;
    Offset position = _doubleTapDetails != null ? _doubleTapDetails!.localPosition : Offset.zero;

    if (_transformationController.value != Matrix4.identity()) {
      endMatrix = Matrix4.identity();
    } else {
      endMatrix = Matrix4.identity()
        ..translate(-position.dx, -position.dy)
        ..scale(2.0)
        ..translate(position.dx / 2, position.dy / 2); // 简单的中心校正
    }

    _animation = Matrix4Tween(
      begin: _transformationController.value,
      end: endMatrix,
    ).animate(CurveTween(curve: Curves.easeInOut).animate(_animationController));

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
          minScale: 1.0,
          maxScale: 3.0,
          // 当处于编辑模式时，禁止缩放，以免手势冲突
          scaleEnabled: widget.enableZoom,
          child: Image.file(
            widget.file,
            fit: BoxFit.contain,
            width: double.infinity,
          ),
        ),
      ),
    );
  }
}