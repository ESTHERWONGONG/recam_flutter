import 'package:flutter/material.dart';
import 'features/camera/camera_screen.dart';
import 'features/editor/filter_screen.dart';
import 'features/editor/frame_screen.dart';
import 'features/editor/sticker_screen.dart';
import 'features/gallery/gallery_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/creator/creator_list_screen.dart';
import 'features/onboarding/permission_screen.dart'; // ✅ 引入引导页

class ReCamApp extends StatelessWidget {
  // ✅ 允许接收外部传入的第一页
  final Widget? home; 
  
  const ReCamApp({super.key, this.home});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ReCam',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.pink,
        scaffoldBackgroundColor: Colors.black,
      ),
      // ✅ 优先使用传入的 home (引导页)，如果没传才去相机
      home: home ?? const CameraScreen(),
      
      // 路由表
      routes: {
        PermissionScreen.route: (_) => const PermissionScreen(),
        CameraScreen.route: (_) => const CameraScreen(),
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