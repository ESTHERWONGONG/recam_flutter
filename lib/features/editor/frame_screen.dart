import 'package:flutter/material.dart';
import 'sticker_screen.dart';

class FrameScreen extends StatelessWidget {
  static const route = '/frame';

  const FrameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String imagePath =
        ModalRoute.of(context)!.settings.arguments as String;

    return Scaffold(
      appBar: AppBar(title: const Text('Frame · 边框')),
      body: Column(
        children: [
          const Expanded(
            child: Center(
              child: Text('这里以后显示边框预览'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    StickerScreen.route,
                    arguments: imagePath,
                  );
                },
                child: const Text('下一步：Sticker'),
              ),
            ),
          )
        ],
      ),
    );
  }
}
