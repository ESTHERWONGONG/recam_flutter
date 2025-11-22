import Flutter
import UIKit

// --------------------------------------------------
// 1. 插件入口：兼任“AI 广播站”
// --------------------------------------------------
public class RecamNativeCameraPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    
    // 全局静态变量，用来存 Flutter 的监听器
    // 这样不管相机 View 什么时候创建，都可以往这里发数据
    public static var aiEventSink: FlutterEventSink?

    public static func register(with registrar: FlutterPluginRegistrar) {
        // A. 注册视图工厂
        let factory = RecamCameraFactory(messenger: registrar.messenger())
        registrar.register(factory, withId: "recam_native_camera_view")
        
        // B. 注册 AI 事件通道 (放在这里注册，保证 App 一启动就有信号)
        let eventChannel = FlutterEventChannel(name: "recam_native_camera/ai_stream", binaryMessenger: registrar.messenger())
        let instance = RecamNativeCameraPlugin()
        eventChannel.setStreamHandler(instance)
    }
    
    // MARK: - FlutterStreamHandler (Flutter 开始监听时调用)
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        // 把 Flutter 的耳朵存起来
        RecamNativeCameraPlugin.aiEventSink = events
        print("📡 Swift Plugin: Flutter 已经连接上 AI 信号塔")
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        RecamNativeCameraPlugin.aiEventSink = nil
        print("📡 Swift Plugin: Flutter 断开了 AI 信号塔")
        return nil
    }
}

// --------------------------------------------------
// 2. 工厂类
// --------------------------------------------------
class RecamCameraFactory: NSObject, FlutterPlatformViewFactory {
    private var messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        return RecamNativeCameraView(
            frame: frame,
            viewIdentifier: viewId,
            arguments: args,
            messenger: messenger
        )
    }
}

// --------------------------------------------------
// 3. 视图类：只负责发数据，不负责建通道
// --------------------------------------------------
class RecamNativeCameraView: NSObject, FlutterPlatformView, CameraViewControllerDelegate {
    
    private var _view: UIView
    private var _controller: CameraViewController
    private var _methodChannel: FlutterMethodChannel

    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        messenger: FlutterBinaryMessenger
    ) {
        _view = UIView(frame: frame)
        _controller = CameraViewController()
        
        // 方法通道还是放在这里，因为它控制具体的相机实例
        _methodChannel = FlutterMethodChannel(name: "recam_native_camera/methods", binaryMessenger: messenger)
        
        super.init()

        _controller.view.frame = _view.bounds
        _controller.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        _view.addSubview(_controller.view)
        
        _controller.delegate = self
        _methodChannel.setMethodCallHandler(handle)
    }

    func view() -> UIView {
        return _view
    }

    // 处理 Flutter 命令
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "takePhoto":
            _controller.capturePhoto()
            result(nil)
            
        case "switchCamera":
            _controller.switchCamera(isFront: false) // 简易切换
            result(nil)
            
        case "setFlashMode":
            if let args = call.arguments as? [String: Any],
               let modeStr = args["mode"] as? String {
                let modeIndex = (modeStr == "on" ? 2 : (modeStr == "auto" ? 1 : 0))
                _controller.updateFlashMode(modeIndex: modeIndex)
            }
            result(nil)
            
        case "setZoom":
             if let args = call.arguments as? [String: Any],
                let zoom = args["zoom"] as? Double {
                 _controller.setZoomFactor(CGFloat(zoom))
             }
             result(nil)

        case "setAspectRatio":
            print("⚠️ setAspectRatio stub")
            result(nil)
            
        case "setQuality":
            print("⚠️ setQuality stub")
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - 引擎回调
    
    func cameraViewController(_ controller: CameraViewController, didCapture image: UIImage) {
        print("✅ Swift Plugin: 拍到照片！尺寸 \(image.size)")
    }
    
    func cameraViewController(_ controller: CameraViewController, didFail error: Error) {
        print("❌ Swift Plugin: 报错 \(error)")
    }
    
    func cameraViewController(_ controller: CameraViewController, didUpdateLiveRecommendation result: AiRecommendResult) {
        // 【关键改动】这里直接往全局 Sink 发送数据
        guard let sink = RecamNativeCameraPlugin.aiEventSink else { return }
        
        let data: [String: Any] = [
            "filmId": result.preset.id,
            "message": result.debugText,
            "score": 0.9,
            "sceneType": "general"
        ]
        sink(data)
    }
}