import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/native_camera_service.dart'; 
import '../../models/ai_recommendation.dart'; // 👈 必须引入这个，才能看懂 AI 数据

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
  
  // 为了保持 Service 实例稳定，我们在 State 里持有一个
  final NativeCameraService _cameraService = NativeCameraService();

  @override
  void initState() {
    super.initState();
    // 启动监听
    _aiStream = _cameraService.aiStream;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final viewfinderHeight = screenWidth * (4 / 3);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),

            Expanded(
              child: Center(
                child: SizedBox(
                  width: screenWidth,
                  height: viewfinderHeight,
                  child: Stack(
                    children: [
                      // 1. 原生相机画面
                      const UiKitView(
                        viewType: 'recam_native_camera_view',
                        layoutDirection: TextDirection.ltr,
                        creationParams: {},
                        creationParamsCodec: StandardMessageCodec(),
                      ),

                      // 2. AI 推荐气泡
                      Positioned(
                        top: 20,
                        right: 16,
                        child: StreamBuilder<AiRecommendation>(
                          stream: _aiStream,
                          builder: (context, snapshot) {
                            // 调试用的：看看有没有数据进来
                            if (snapshot.hasData) {
                                print("Dart收到AI数据: ${snapshot.data?.message}");
                            } else if (snapshot.hasError) {
                                print("Dart收到错误: ${snapshot.error}");
                            }

                            if (!snapshot.hasData) return const SizedBox();
                            
                            final recommendation = snapshot.data!;
                            // 如果消息为空，就不显示
                            if (recommendation.message.isEmpty) return const SizedBox();

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.yellowAccent.withOpacity(0.8)),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4)
                                ]
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
                      
                      // 3. 变焦控制 (0.5 / 1 / 2)
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

  // --- 组件构建 ---

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

  Widget _buildCapturePanel() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(icon: const Icon(Icons.photo_library, color: Colors.white, size: 32), onPressed: () {}),
        GestureDetector(
          onTap: () {
            print("📸 咔嚓");
            _cameraService.takePhoto(); 
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