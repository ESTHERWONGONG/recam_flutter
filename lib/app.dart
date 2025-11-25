import 'package:flutter/material.dart';
import 'features/camera/camera_screen.dart';
import 'features/gallery/gallery_screen.dart';
import 'features/settings/settings_screen.dart';

class ReCamApp extends StatelessWidget {
  // ✅ [修复] 定义 home 变量，用来接收 main.dart 传过来的页面
  final Widget home;

  // ✅ [修复] 构造函数里加上 required this.home
  const ReCamApp({super.key, required this.home});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ReCam',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.black,
      ),
      
      // ✅ [核心修复] 使用 main.dart 传来的 home 作为启动页
      // (不要再用 initialRoute 了，因为它会覆盖 home)
      home: home,
      
      // 路由表保留，用于后续跳转
      routes: {
        CameraScreen.route: (_) => const CameraScreen(),
        GalleryScreen.route: (_) => const GalleryScreen(),
        '/settings': (_) => const SettingsScreen(),
      },
    );
  }
}