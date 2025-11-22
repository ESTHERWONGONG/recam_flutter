import 'dart:io';

import 'package:flutter/material.dart';
import 'frame_screen.dart';

class FilterScreen extends StatelessWidget {
  static const route = '/filter';

  const FilterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String imagePath =
        ModalRoute.of(context)!.settings.arguments as String;

    return Scaffold(
      appBar: AppBar(title: const Text('Filter · 滤镜')),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: Colors.black,
              child: Center(
                child: Image.file(
                  File(imagePath),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Colors.orange.withOpacity(0.15),
            child: Row(
              children: const [
                Icon(Icons.auto_awesome),
                SizedBox(width: 8),
                Expanded(
                  child: Text('AI 推荐占位：未来由 Swift/CoreML 推送'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text('这里以后是 LUT 滤镜列表'),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    FrameScreen.route,
                    arguments: imagePath,
                  );
                },
                child: const Text('下一步：Frame'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
