import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../gallery/gallery_screen.dart';
import '../settings/settings_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});
  static const route = '/camera';

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  Future<void>? _initFuture;

  // UI 状态：闪光 / 画幅比例 / 是否展示滤镜面板
  FlashMode _flashMode = FlashMode.off;
  double _aspectRatio = 3 / 4; // 3:4 默认
  bool _showFilterPanel = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera({CameraLensDirection preferred = CameraLensDirection.back}) async {
    try {
      _cameras = await availableCameras();

      // 找到指定方向的镜头，找不到就用第一个
      CameraDescription camera = _cameras.first;
      final candidates = _cameras.where((c) => c.lensDirection == preferred);
      if (candidates.isNotEmpty) {
        camera = candidates.first;
      }

      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await controller.initialize();
      await controller.setFlashMode(_flashMode);

      _controller?.dispose();
      _controller = controller;
      _initFuture = Future.value();

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('initCamera error: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _onCapture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    try {
      final file = await controller.takePicture();
      if (!mounted) return;

      // ✅ 按你的流程：拍完 → 进入 Gallery，而不是 Filter
      Navigator.pushNamed(
        context,
        GalleryScreen.route,
        arguments: file.path,
      );
    } catch (e) {
      debugPrint('takePicture error: $e');
    }
  }

  Future<void> _toggleFlash() async {
    final controller = _controller;
    if (controller == null) return;

    // 先用一个简单的循环：off → auto → always
    setState(() {
      switch (_flashMode) {
        case FlashMode.off:
          _flashMode = FlashMode.auto;
          break;
        case FlashMode.auto:
          _flashMode = FlashMode.always;
          break;
        case FlashMode.always:
        case FlashMode.torch:
          _flashMode = FlashMode.off;
          break;
      }
    });

    try {
      await controller.setFlashMode(_flashMode);
    } catch (e) {
      debugPrint('setFlashMode error: $e');
    }
  }

  void _toggleAspectRatio() {
    // 先简单：3:4 ↔ 1:1
    setState(() {
      if (_aspectRatio == 3 / 4) {
        _aspectRatio = 1 / 1;
      } else {
        _aspectRatio = 3 / 4;
      }
    });

    // 未来这里会调用 Swift 插件去改裁切区域，现在只影响 UI
  }

  Future<void> _switchCamera() async {
    if (_cameras.isEmpty) return;

    final current = _controller?.description;
    if (current == null) return;

    CameraLensDirection targetDirection;
    if (current.lensDirection == CameraLensDirection.back) {
      targetDirection = CameraLensDirection.front;
    } else {
      targetDirection = CameraLensDirection.back;
    }

    await _initCamera(preferred: targetDirection);
  }

  void _openSettings() {
    Navigator.pushNamed(context, SettingsScreen.route);
  }

  void _openGallery() {
    Navigator.pushNamed(context, GalleryScreen.route);
  }

  void _toggleFilterPanel() {
    setState(() {
      _showFilterPanel = !_showFilterPanel;
    });
  }

  void _onFramePressed() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('边框功能稍后在编辑页中提供，这里只是预留入口。')),
    );
  }

  void _onStickerPressed() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('贴纸功能稍后在编辑页中提供，这里只是预留入口。')),
    );
  }

  IconData _flashIcon() {
    switch (_flashMode) {
      case FlashMode.off:
        return Icons.flash_off;
      case FlashMode.auto:
        return Icons.flash_auto;
      case FlashMode.always:
      case FlashMode.torch:
        return Icons.flash_on;
    }
  }

  String _aspectLabel() {
    if (_aspectRatio == 3 / 4) return '3:4';
    if (_aspectRatio == 1 / 1) return '1:1';
    return 'AR';
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // 顶部画板：设置 / 闪光 / 比例 / 翻转镜头
            _buildTopToolbar(),

            // 中间：取景 3:4 区域（Live Preview）
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: _aspectRatio,
                  child: Container(
                    color: Colors.black,
                    child: controller == null
                        ? const Center(child: CircularProgressIndicator())
                        : CameraPreview(controller),
                  ),
                ),
              ),
            ),

            // 底部画板：上排（边框 / 贴纸）+ 下排（相册 / 快门 / 滤镜 或 滤镜列表）
            _buildBottomPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 56,
      color: Colors.black.withOpacity(0.6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _TopIconButton(
            label: '设置',
            icon: Icons.settings_outlined,
            onTap: _openSettings,
          ),
          _TopIconButton(
            label: '闪光',
            icon: _flashIcon(),
            onTap: _toggleFlash,
          ),
          _TopIconButton(
            label: _aspectLabel(),
            icon: Icons.crop_3_2_outlined,
            onTap: _toggleAspectRatio,
          ),
          _TopIconButton(
            label: '翻转',
            icon: Icons.cameraswitch_outlined,
            onTap: _switchCamera,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPanel() {
    return Container(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      color: Colors.black.withOpacity(0.8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 上排：边框 / 贴纸
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _onFramePressed,
                  child: const Text(
                    '边框',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                TextButton(
                  onPressed: _onStickerPressed,
                  child: const Text(
                    '贴纸',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // 下排：相册 / 快门 / 滤镜  或  滤镜选择面板
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _showFilterPanel
                ? _buildFilterPanel()
                : _buildMainBottomBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildMainBottomBar() {
    return Padding(
      key: const ValueKey('main_bar'),
      padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 相册
          IconButton(
            onPressed: _openGallery,
            icon: const Icon(Icons.photo_library_outlined),
            color: Colors.white,
            iconSize: 28,
          ),

          // 快门
          GestureDetector(
            onTap: _onCapture,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
              ),
              child: Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),

          // 滤镜
          IconButton(
            onPressed: _toggleFilterPanel,
            icon: const Icon(Icons.filter_vintage_outlined),
            color: Colors.white,
            iconSize: 28,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPanel() {
    // 先做一个假滤镜列表，未来接 LUT & CoreML
    final filters = ['原片', 'Fuji 400H', 'Portra 160', 'C200', 'BW', '自定义'];

    return Container(
      key: const ValueKey('filter_panel'),
      height: 96,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // 顶部一行：标题 + 关闭
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '滤镜',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              IconButton(
                onPressed: _toggleFilterPanel,
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // 水平滚动滤镜选项
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final name = filters[index];
                return GestureDetector(
                  onTap: () {
                    // TODO: 这里以后接真实 LUT 切换
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('切换滤镜：$name（暂为占位）')),
                    );
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white),
                    ),
                    child: Text(
                      name,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TopIconButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _TopIconButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
