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
  // 权限状态
  bool _cameraGranted = false;
  bool _micGranted = false;
  bool _photoGranted = false;
  
  // 设置状态
  bool _autoSaveEnabled = true;

  // ✅ [新增] 防抖锁：是否正在请求中？
  bool _isRequesting = false;

  @override
  void initState() {
    super.initState();
    _checkInitialStatus();
  }

  // 1. 检查状态 (只看不请求)
  Future<void> _checkInitialStatus() async {
    final camera = await Permission.camera.status;
    final mic = await Permission.microphone.status;
    final photos = await Permission.photos.status;
    final photosAdd = await Permission.photosAddOnly.status; 

    if (mounted) {
      setState(() {
        _cameraGranted = camera.isGranted;
        _micGranted = mic.isGranted;
        _photoGranted = photos.isGranted || photos.isLimited || photosAdd.isGranted || photosAdd.isLimited;
      });
    }
  }

  // 2. ✅ [修改] 请求权限 (加锁防抖)
  Future<void> _requestAllPermissions() async {
    // 如果正在请求中，直接无视点击，防止报错
    if (_isRequesting) return;

    setState(() => _isRequesting = true); // 🔒 上锁

    try {
      print("🔘 UI: 开始请求权限...");
      
      // 这是一个耗时操作，iOS 会一个个弹窗，用户需要时间点击
      Map<Permission, PermissionStatus> statuses = await [
        Permission.camera,
        Permission.microphone,
        Permission.photos,
      ].request();

      print("✅ UI: 请求完成");

      if (mounted) {
        setState(() {
          _cameraGranted = statuses[Permission.camera]!.isGranted;
          _micGranted = statuses[Permission.microphone]!.isGranted;
          
          final p = statuses[Permission.photos]!;
          _photoGranted = p.isGranted || p.isLimited;
        });
      }
    } catch (e) {
      print("❌ 权限请求异常: $e");
    } finally {
      // 无论成功失败，最后都要解锁
      if (mounted) {
        setState(() => _isRequesting = false); // 🔓 解锁
      }
    }
  }

  // 3. 进入 App
  Future<void> _enterApp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_completed_onboarding', true);
    await prefs.setBool('auto_save_to_gallery', _autoSaveEnabled);

    if (mounted) {
      Navigator.pushReplacementNamed(context, CameraScreen.route);
    }
  }

  @override
  Widget build(BuildContext context) {
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
              
              // --- 必要权限 ---
              const Text("必要权限", style: TextStyle(color: Colors.yellowAccent, fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              _buildPermissionItem("相机访问", Icons.camera_alt, _cameraGranted),
              _buildPermissionItem("麦克风权限", Icons.mic, _micGranted),
              _buildPermissionItem("相册读写", Icons.photo_library, _photoGranted),

              // --- 授权按钮 (未授权时显示) ---
              if (!canEnter)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Center(
                    // ✅ [修改] 如果正在请求，显示转圈圈
                    child: _isRequesting 
                      ? const CircularProgressIndicator(color: Colors.blueAccent)
                      : TextButton(
                          onPressed: _requestAllPermissions,
                          child: const Text("点击一次性授权所有", style: TextStyle(color: Colors.blueAccent, fontSize: 16)),
                        ),
                  ),
                ),

              const Spacer(),
              Divider(color: Colors.grey[800]),
              const SizedBox(height: 10),
              
              // --- 自动保存开关 ---
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
                    onChanged: (val) => setState(() => _autoSaveEnabled = val),
                  ),
                ],
              ),
              
              const SizedBox(height: 40),

              // --- 底部大按钮 ---
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: canEnter ? _enterApp : null,
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

  Widget _buildPermissionItem(String label, IconData icon, bool isGranted) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(width: 16),
          Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 18))),
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