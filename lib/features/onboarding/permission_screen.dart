import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../camera/camera_screen.dart';

class PermissionScreen extends StatefulWidget {
  static const route = '/permission';
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> {
  // 权限状态 (❌ = false, ✅ = true)
  bool _cameraGranted = false;
  bool _micGranted = false;
  bool _photoGranted = false;
  
  // 偏好设置 (默认开启自动保存)
  bool _autoSaveEnabled = true;

  @override
  void initState() {
    super.initState();
    _checkInitialStatus();
  }

  // 1. 刚进来时，检查一下当前状态
  Future<void> _checkInitialStatus() async {
    final camera = await Permission.camera.status;
    final mic = await Permission.microphone.status;
    final photos = await Permission.photos.status;
    final photosAdd = await Permission.photosAddOnly.status; 

    if (mounted) {
      setState(() {
        _cameraGranted = camera.isGranted;
        _micGranted = mic.isGranted;
        // iOS 14+ 可能是 limited (部分访问)，也算通过
        _photoGranted = photos.isGranted || photos.isLimited || photosAdd.isGranted || photosAdd.isLimited;
      });
    }
  }

  // 2. 点击按钮：请求所有必要权限
  Future<void> _requestAllPermissions() async {
    // 这是一个数组，iOS 会依次弹窗
    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.microphone,
      Permission.photos,
    ].request();

    if (mounted) {
      setState(() {
        _cameraGranted = statuses[Permission.camera]!.isGranted;
        _micGranted = statuses[Permission.microphone]!.isGranted;
        
        final p = statuses[Permission.photos]!;
        _photoGranted = p.isGranted || p.isLimited;
      });
    }
  }

  // 3. 进入 App (存配置 + 跳转)
  Future<void> _enterApp() async {
    final prefs = await SharedPreferences.getInstance();
    
    // A. 记录“用户已完成引导”，下次不显示这页了
    await prefs.setBool('has_completed_onboarding', true);
    
    // B. 记录“自动保存”的开关状态 (供相机页读取)
    await prefs.setBool('auto_save_to_gallery', _autoSaveEnabled);

    // C. 跳转相机
    if (mounted) {
      // pushReplacementNamed 意味着“关门”，用户按返回键回不到这里
      Navigator.pushReplacementNamed(context, CameraScreen.route);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 只有 3 个硬性指标都满足，才能进门
    final bool canEnter = _cameraGranted && _micGranted && _photoGranted;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              const Text("欢迎来到 ReCam", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text("在开启胶片之旅前，我们需要配置以下权限：", style: TextStyle(color: Colors.grey, fontSize: 16)),
              
              const SizedBox(height: 40),
              
              // --- 必选项 (上部) ---
              const Text("必要权限 (必须开启)", style: TextStyle(color: Colors.yellowAccent, fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              _buildPermissionItem("相机访问", Icons.camera_alt, _cameraGranted),
              _buildPermissionItem("麦克风权限", Icons.mic, _micGranted),
              _buildPermissionItem("相册读写", Icons.photo_library, _photoGranted),

              // 如果还没全绿，显示这个授权按钮
              if (!canEnter)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Center(
                    child: TextButton(
                      onPressed: _requestAllPermissions,
                      child: const Text("点击一次性授权所有", style: TextStyle(color: Colors.blueAccent, fontSize: 16)),
                    ),
                  ),
                ),

              const Spacer(),
              
              // --- 分割线 ---
              Divider(color: Colors.grey[800]),
              const SizedBox(height: 10),
              
              // --- 可选项 (下部) ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("自动保存到系统相册", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      Text("拍摄后自动落袋，无需手动保存", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                  Switch(
                    value: _autoSaveEnabled,
                    activeColor: Colors.yellowAccent,
                    trackColor: MaterialStateProperty.all(Colors.grey[800]),
                    onChanged: (val) {
                      setState(() => _autoSaveEnabled = val);
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: 40),

              // --- 底部大按钮 ---
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: canEnter ? _enterApp : null, // 没权限时禁用点击
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.yellowAccent,
                    disabledBackgroundColor: Colors.grey[900],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    canEnter ? "开启 ReCam" : "请先授权必要权限",
                    style: TextStyle(
                      color: canEnter ? Colors.black : Colors.grey,
                      fontSize: 18,
                      fontWeight: FontWeight.bold
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 辅助组件：权限列表项
  Widget _buildPermissionItem(String label, IconData icon, bool isGranted) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(width: 16),
          Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 18))),
          // 状态图标：绿勾 or 灰圈
          Icon(
            isGranted ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isGranted ? Colors.green : Colors.grey,
            size: 28,
          ),
        ],
      ),
    );
  }
}