import 'dart:io';
import 'package:flutter/material.dart';

class GalleryScreen extends StatelessWidget {
  // ✅ 必须有这一行，外面的 camera_screen 才能通过 .route 找到它
  static const route = '/gallery';

  const GalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 获取传过来的图片路径
    final args = ModalRoute.of(context)?.settings.arguments;
    final String? imagePath = args is String ? args : null;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Gallery · 成片', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white), // 返回箭头变白
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
}