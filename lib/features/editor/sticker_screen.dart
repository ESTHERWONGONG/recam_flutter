import 'package:flutter/material.dart';
import '../gallery/gallery_screen.dart';

class StickerScreen extends StatelessWidget {
  static const route = '/sticker';

  const StickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String imagePath =
        ModalRoute.of(context)!.settings.arguments as String;

    return Scaffold(
      appBar: AppBar(title: const Text('Sticker · 贴纸')),
      body: Column(
        children: [
          const Expanded(
            child: Center(
              child: Text('这里以后是贴纸编辑画布'),
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
                    GalleryScreen.route,
                    arguments: imagePath,
                  );
                },
                child: const Text('完成并保存成片（先跳 Gallery）'),
              ),
            ),
          )
        ],
      ),
    );
  }
}
