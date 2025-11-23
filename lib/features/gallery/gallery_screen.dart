import 'dart:io';
import 'package:flutter/material.dart';
import '../../services/native_camera_service.dart'; // 引入 Service

class GalleryScreen extends StatelessWidget {
  static const route = '/gallery';

  const GalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 获取路径
    final args = ModalRoute.of(context)?.settings.arguments;
    final String? imagePath = args is String ? args : null;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Gallery · 成片', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // ✅ 右上角的黄色保存按钮
          if (imagePath != null)
            IconButton(
              icon: const Icon(Icons.download_rounded, color: Colors.yellowAccent, size: 28),
              onPressed: () => _savePhoto(context, imagePath),
            )
        ],
      ),
      body: Center(
        child: imagePath == null
            ? const Text('当前无成片', style: TextStyle(color: Colors.white))
            : _buildImage(imagePath),
      ),
    );
  }

  Widget _buildImage(String path) {
    if (path.startsWith('assets/')) {
      return Image.asset(path, fit: BoxFit.contain);
    } else {
      return Image.file(File(path), fit: BoxFit.contain);
    }
  }

  // ✅ 点击后的保存逻辑
  Future<void> _savePhoto(BuildContext context, String path) async {
    // 1. 显示 Loading
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('正在保存...'), duration: Duration(milliseconds: 500)),
    );

    // 2. 调用 Service
    final success = await NativeCameraService().saveToGallery(path);
    
    // 3. 显示结果
    if (context.mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 已保存到系统相册！'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ 保存失败 (请在设置里允许访问相册)'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}