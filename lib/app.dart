import 'package:flutter/material.dart';

import 'features/camera/camera_screen.dart';
import 'features/editor/filter_screen.dart';
import 'features/editor/frame_screen.dart';
import 'features/editor/sticker_screen.dart';
import 'features/gallery/gallery_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/creator/creator_list_screen.dart';

class ReCamApp extends StatelessWidget {
  const ReCamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ReCam',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.pink,
      ),
      home: const CameraScreen(),
      routes: {
        FilterScreen.route: (_) => const FilterScreen(),
        FrameScreen.route: (_) => const FrameScreen(),
        StickerScreen.route: (_) => const StickerScreen(),
        GalleryScreen.route: (_) => const GalleryScreen(),
        CreatorListScreen.route: (_) => const CreatorListScreen(),
        SettingsScreen.route: (_) => const SettingsScreen(),
      },
    );
  }
}
