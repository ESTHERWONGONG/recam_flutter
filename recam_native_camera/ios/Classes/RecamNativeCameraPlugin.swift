import Flutter
import UIKit

// 1. 插件入口
public class RecamNativeCameraPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    public static var aiEventSink: FlutterEventSink?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let factory = RecamCameraFactory(messenger: registrar.messenger())
        registrar.register(factory, withId: "recam_native_camera_view")
        
        let eventChannel = FlutterEventChannel(name: "recam_native_camera/ai_stream", binaryMessenger: registrar.messenger())
        let instance = RecamNativeCameraPlugin()
        eventChannel.setStreamHandler(instance)
    }
    
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        RecamNativeCameraPlugin.aiEventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        RecamNativeCameraPlugin.aiEventSink = nil
        return nil
    }
}

// 2. 工厂类
class RecamCameraFactory: NSObject, FlutterPlatformViewFactory {
    private var messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        return RecamNativeCameraView(frame: frame, viewIdentifier: viewId, arguments: args, messenger: messenger)
    }
}

// 3. 视图类（核心修改：增加了存图逻辑）
class RecamNativeCameraView: NSObject, FlutterPlatformView, CameraViewControllerDelegate {
    
    private var _view: UIView
    private var _controller: CameraViewController
    private var _methodChannel: FlutterMethodChannel
    private var _takePhotoResult: FlutterResult? // 暂存回调

    init(frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?, messenger: FlutterBinaryMessenger) {
        _view = UIView(frame: frame)
        _controller = CameraViewController()
        _methodChannel = FlutterMethodChannel(name: "recam_native_camera/methods", binaryMessenger: messenger)
        
        super.init()

        _controller.view.frame = _view.bounds
        _controller.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        _view.addSubview(_controller.view)
        
        _controller.delegate = self
        _methodChannel.setMethodCallHandler(handle)
    }

    func view() -> UIView { return _view }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "takePhoto":
            // 暂存 result，等拍完再回话
            _takePhotoResult = result
            print("📸 Swift: 收到拍照请求...")
            _controller.capturePhoto()
            
        case "switchCamera":
            _controller.switchCamera(isFront: false)
            result(nil)
            
        case "setFlashMode":
            if let args = call.arguments as? [String: Any], let modeStr = args["mode"] as? String {
                let modeIndex = (modeStr == "on" ? 2 : (modeStr == "auto" ? 1 : 0))
                _controller.updateFlashMode(modeIndex: modeIndex)
            }
            result(nil)
            
        case "setZoom":
             if let args = call.arguments as? [String: Any], let zoom = args["zoom"] as? Double {
                 _controller.setZoomFactor(CGFloat(zoom))
             }
             result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - 引擎回调
    func cameraViewController(_ controller: CameraViewController, didCapture image: UIImage) {
        print("✅ Swift: 拍到照片，正在写入临时文件...")
        
        // 生成文件名
        let fileName = "recam_\(Int(Date().timeIntervalSince1970)).jpg"
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        DispatchQueue.global(qos: .background).async {
            do {
                // 压缩并写入
                if let data = image.jpegData(compressionQuality: 0.9) {
                    try data.write(to: fileURL)
                    print("💾 Saved to: \(fileURL.path)")
                    
                    DispatchQueue.main.async {
                        // 回复 Flutter：成功了，路径给你！
                        if let callback = self._takePhotoResult {
                            callback(fileURL.path)
                            self._takePhotoResult = nil
                        }
                    }
                }
            } catch {
                print("❌ Save Error: \(error)")
                DispatchQueue.main.async {
                    self._takePhotoResult?(FlutterError(code: "SAVE_ERROR", message: error.localizedDescription, details: nil))
                    self._takePhotoResult = nil
                }
            }
        }
    }
    
    func cameraViewController(_ controller: CameraViewController, didFail error: Error) {
        _takePhotoResult?(FlutterError(code: "CAMERA_ERROR", message: error.localizedDescription, details: nil))
        _takePhotoResult = nil
    }
    
    func cameraViewController(_ controller: CameraViewController, didUpdateLiveRecommendation result: AiRecommendResult) {
        guard let sink = RecamNativeCameraPlugin.aiEventSink else { return }
        sink(["filmId": result.preset.id, "message": result.debugText])
    }
}