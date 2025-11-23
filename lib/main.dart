import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'features/onboarding/permission_screen.dart';
import 'features/camera/camera_screen.dart';

void main() async {
  // 1. 必须先初始化 Flutter 绑定，才能用 SharedPreferences
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. 查本地记录：是老用户吗？
  final prefs = await SharedPreferences.getInstance();
  final bool hasCompletedOnboarding = prefs.getBool('has_completed_onboarding') ?? false;

  // 3. 决定第一页去哪
  // 如果完成了引导 -> 去相机
  // 如果没完成 -> 去权限引导页
  final Widget firstScreen = hasCompletedOnboarding 
      ? const CameraScreen() 
      : const PermissionScreen();

  // 4. 启动 App (用 Wrapper 包装一下传参数)
  runApp(ReCamAppWrapper(initialScreen: firstScreen));
}

// 一个简单的包装器，负责把 firstScreen 传给 ReCamApp
class ReCamAppWrapper extends StatelessWidget {
  final Widget initialScreen;
  const ReCamAppWrapper({super.key, required this.initialScreen});

  @override
  Widget build(BuildContext context) {
    // 这里的 home 参数会传给 app.dart
    return ReCamApp(home: initialScreen);
  }
}