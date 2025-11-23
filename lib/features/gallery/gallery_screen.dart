import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // 用于格式化时间
import '../../services/native_camera_service.dart';
import '../../data/photo_storage.dart'; // 引入数据层

class GalleryScreen extends StatefulWidget {
  static const route = '/gallery';

  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  // 当前显示的模式：null=列表模式，String=大图预览模式
  String? _viewingPath;
  // 数据列表
  List<ReCamPhoto> _photos = [];
  bool _isLoading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 1. 获取路由参数 (如果是刚拍完照进来的，会有路径)
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String) {
      _viewingPath = args;
    }
    // 2. 加载历史数据
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    final list = await PhotoStorage.getAllPhotos();
    if (mounted) {
      setState(() {
        _photos = list;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 根据是否有 _viewingPath 决定显示什么
    final bool isPreviewMode = _viewingPath != null;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(isPreviewMode ? '预览' : 'Gallery (${_photos.length})', 
          style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (isPreviewMode) {
              // 如果是大图模式，点返回先回到列表 (如果是直接从相机跳过来的，逻辑要微调，这里简单处理直接pop)
              // 为了体验更好：如果刚拍完，点返回应该是回到相机
              // 如果是从列表点进大图，点返回回到列表
              // 这里统一：Navigator.pop
              Navigator.pop(context);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          // 只有在大图模式下，才显示“保存系统相册”按钮
          if (isPreviewMode)
            IconButton(
              icon: const Icon(Icons.download_rounded, color: Colors.yellowAccent, size: 28),
              onPressed: () => _saveToSystemAlbum(context, _viewingPath!),
            )
        ],
      ),
      // 核心：双模式切换
      body: isPreviewMode 
          ? _buildPreviewView(_viewingPath!) 
          : _buildGridView(),
    );
  }

  // --- 模式 A: 大图预览 ---
  Widget _buildPreviewView(String path) {
    return Center(
      child: Image.file(File(path), fit: BoxFit.contain),
    );
  }

  // --- 模式 B: 网格列表 ---
  Widget _buildGridView() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_photos.isEmpty) {
      return const Center(child: Text("还没有照片，快去拍一张吧！", style: TextStyle(color: Colors.grey)));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, // 一行 3 个
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        childAspectRatio: 3 / 4, // 照片比例
      ),
      itemCount: _photos.length,
      itemBuilder: (context, index) {
        final photo = _photos[index];
        return GestureDetector(
          onTap: () {
            // 点击缩略图 -> 变大图
            setState(() {
              _viewingPath = photo.path;
            });
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(
                File(photo.path),
                fit: BoxFit.cover,
              ),
              // 显示时间
              Positioned(
                bottom: 4, right: 4,
                child: Text(
                  DateFormat('HH:mm').format(photo.createdAt),
                  style: const TextStyle(color: Colors.white, fontSize: 10, shadows: [Shadow(blurRadius: 2, color: Colors.black)]),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  // 保存到系统相册
  Future<void> _saveToSystemAlbum(BuildContext context, String path) async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('正在保存...'), duration: Duration(milliseconds: 500)));
    final success = await NativeCameraService().saveToGallery(path);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '✅ 已保存到系统相册！' : '❌ 保存失败'),
          backgroundColor: success ? Colors.green : Colors.red,
        )
      );
    }
  }
}