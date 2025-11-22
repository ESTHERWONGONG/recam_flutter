import 'dart:io';
import 'package:flutter/material.dart';

class GalleryScreen extends StatelessWidget {
  static const route = '/gallery';

  const GalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final String? imagePath = args is String ? args : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Gallery · 成片')),
      body: Center(
        child: imagePath == null
            ? const Text('当前无成片')
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
