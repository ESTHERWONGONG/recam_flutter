import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; 
import '../../services/native_camera_service.dart';
import '../../data/photo_storage.dart'; 

class GalleryScreen extends StatefulWidget {
  static const route = '/gallery';
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  int? _currentIndex; // 模式：null=网格, int=当前大图索引
  List<ReCamPhoto> _photos = [];
  bool _isLoading = true;
  PageController? _pageController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isLoading) {
        _loadPhotos();
    }
  }

  Future<void> _loadPhotos() async {
    final list = await PhotoStorage.getAllPhotos();
    if (mounted) {
      setState(() {
        _photos = list;
        _isLoading = false;
        
        // 检查是否是刚拍照跳转过来的
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
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isPreviewMode = _currentIndex != null;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        // 预览模式显示标题，网格模式标题可以简单点
        title: Text(isPreviewMode ? '预览' : 'Gallery', 
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true, 
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20), // 更现代的返回箭头
          onPressed: () {
            if (isPreviewMode) {
              setState(() {
                _currentIndex = null;
                _pageController?.dispose();
                _pageController = null;
              });
            } else {
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          if (isPreviewMode && _photos.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.download_rounded, color: Colors.yellowAccent, size: 26),
              onPressed: () => _saveToSystemAlbum(context, _photos[_currentIndex!].path),
            )
        ],
      ),
      // 移除 SafeArea 的 bottom，让图片能沉浸到底部
      body: isPreviewMode 
          ? _buildPageView() 
          : _buildGridView(),
    );
  }

  // --- 大图浏览模式 ---
  Widget _buildPageView() {
    if (_photos.isEmpty) return const SizedBox();
    
    return PageView.builder(
      controller: _pageController,
      itemCount: _photos.length,
      onPageChanged: (index) => setState(() => _currentIndex = index),
      itemBuilder: (context, index) {
        final photo = _photos[index];
        return Center(
          child: InteractiveViewer(
            child: Image.file(File(photo.path), fit: BoxFit.contain),
          ),
        );
      },
    );
  }

  // --- ✅ [核心修改] 网格模式 ---
  Widget _buildGridView() {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Colors.yellowAccent));
    if (_photos.isEmpty) return const Center(child: Text("还没有照片", style: TextStyle(color: Colors.grey)));

    return GridView.builder(
      // ✅ [修改] 边距极小，往上顶
      padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 0), 
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, // 保持3列
        crossAxisSpacing: 1.5, // 间距调小
        mainAxisSpacing: 1.5,
        // ✅ [修改] 宽高比：0.66 (大约 2:3)
        // 数值越小，格子越高。之前是 0.75(3:4)，现在 0.66 会显得更修长
        childAspectRatio: 0.66, 
      ),
      itemCount: _photos.length,
      itemBuilder: (context, index) {
        final photo = _photos[index];
        return GestureDetector(
          onTap: () => _enterPreviewMode(index),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 图片铺满，裁剪多余部分
              Image.file(File(photo.path), fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(color: Colors.grey[900], child: const Icon(Icons.broken_image, color: Colors.grey));
                },
              ),
              // 渐变遮罩 (为了让时间文字看清)
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  height: 30,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                    ),
                  ),
                ),
              ),
              // 时间戳
              Positioned(
                bottom: 4, right: 4,
                child: Text(
                  DateFormat('MM-dd HH:mm').format(photo.createdAt), // 显示日期+时间
                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w500),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveToSystemAlbum(BuildContext context, String path) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('正在保存...'), duration: Duration(milliseconds: 500))
    );
    final success = await NativeCameraService().saveToGallery(path);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '✅ 已保存到系统相册' : '❌ 保存失败，请检查权限'), 
          backgroundColor: success ? Colors.green : Colors.red,
          duration: const Duration(seconds: 1),
        )
      );
    }
  }
}