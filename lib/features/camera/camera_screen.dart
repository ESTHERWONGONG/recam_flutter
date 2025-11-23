import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/native_camera_service.dart'; 
import '../../models/ai_recommendation.dart'; 
import '../../data/photo_storage.dart'; // ✅ [新增] 引入数据存储管家

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});
  static const route = '/camera';

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  // 状态变量
  bool _isFilterMode = false;
  String _flashMode = "off";
  
  // AI 数据流
  Stream<AiRecommendation>? _aiStream;
  
  // 实例化 Service
  final NativeCameraService _cameraService = NativeCameraService();

  @override
  void initState() {
    super.initState();
    // 启动 AI 监听
    _aiStream = _cameraService.aiStream;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // 3:4 取景框高度
    final viewfinderHeight = screenWidth * (4 / 3);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // 1. 顶部工具栏
            _buildTopBar(),

            // 2. 中间取景区域
            Expanded(
              child: Center(
                child: SizedBox(
                  width: screenWidth,
                  height: viewfinderHeight,
                  child: Stack(
                    children: [
                      // A. 原生相机视图 (Swift)
                      const UiKitView(
                        viewType: 'recam_native_camera_view',
                        layoutDirection: TextDirection.ltr,
                        creationParams: {},
                        creationParamsCodec: StandardMessageCodec(),
                      ),

                      // B. AI 推荐气泡
                      Positioned(
                        top: 20,
                        right: 16,
                        child: StreamBuilder<AiRecommendation>(
                          stream: _aiStream,
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) return const SizedBox();
                            
                            final recommendation = snapshot.data!;
                            if (recommendation.message.isEmpty) return const SizedBox();

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.yellowAccent.withOpacity(0.8)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.auto_awesome, color: Colors.yellowAccent, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    recommendation.message, 
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      
                      // C. 变焦按钮
                      Positioned(
                        bottom: 16,
                        left: 0, right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildZoomBtn(0.5),
                            const SizedBox(width: 24),
                            _buildZoomBtn(1.0),
                            const SizedBox(width: 24),
                            _buildZoomBtn(2.0),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 3. 底部操作板
            Container(
              height: 160,
              color: const Color(0xFF111111),
              child: _isFilterMode ? _buildFilterPanel() : _buildCapturePanel(),
            ),
          ],
        ),
      ),
    );
  }

  // --- 顶部栏 ---
  Widget _buildTopBar() {
    return Container(
      height: 50,
      color: Colors.black,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(icon: const Icon(Icons.settings, color: Colors.white), onPressed: () {}),
          IconButton(
            icon: Icon(_flashMode == 'on' ? Icons.flash_on : Icons.flash_off, color: Colors.white),
            onPressed: () {
              final newMode = _flashMode == 'off' ? 'auto' : (_flashMode == 'auto' ? 'on' : 'off');
              setState(() => _flashMode = newMode);
              _cameraService.setFlashMode(newMode);
            },
          ),
          const Text("3:4", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios, color: Colors.white), 
            onPressed: () => _cameraService.switchCamera()
          ),
        ],
      ),
    );
  }

  // --- 底部拍摄面板 ---
  Widget _buildCapturePanel() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // ✅ [修改] 左侧相册按钮：点击进入“历史列表模式”
        IconButton(
          icon: const Icon(Icons.photo_library, color: Colors.white, size: 32),
          onPressed: () {
             // 不传 path 参数，GalleryScreen 就会显示网格列表
             Navigator.pushNamed(context, '/gallery');
          },
        ),
        
        // 📸 快门按钮
        GestureDetector(
          onTap: () async {
            print("📸 UI: 点击快门...");
            
            // 1. 物理拍照
            final path = await _cameraService.takePhoto();
            
            if (path.isNotEmpty && mounted) {
              print("💙 收到路径: $path");

              // 2. ✅ [新增] 呼叫管家记账 (持久化保存)
              await PhotoStorage.savePhoto(path);

              // 3. 跳转预览 (带参数=大图预览模式)
              Navigator.pushNamed(
                context,
                '/gallery',
                arguments: path,
              );
            }
          },
          child: Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFCE2029),
              border: Border.all(color: Colors.white, width: 4),
            ),
          ),
        ),

        IconButton(
          icon: const Icon(Icons.filter_vintage, color: Colors.yellowAccent, size: 32),
          onPressed: () => setState(() => _isFilterMode = true),
        ),
      ],
    );
  }

  // --- 滤镜面板 ---
  Widget _buildFilterPanel() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("选择胶片", style: TextStyle(color: Colors.white)),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(5, (index) => Container(
              margin: const EdgeInsets.all(8),
              width: 60, height: 60,
              color: Colors.grey[800],
              child: Center(child: Text("C$index", style: const TextStyle(color: Colors.white))),
            )),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
          onPressed: () => setState(() => _isFilterMode = false),
        )
      ],
    );
  }

  // --- 变焦按钮 ---
  Widget _buildZoomBtn(double zoom) {
    return GestureDetector(
      onTap: () => _cameraService.setZoom(zoom),
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withOpacity(0.5),
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        alignment: Alignment.center,
        child: Text("${zoom}x", style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    );
  }
}