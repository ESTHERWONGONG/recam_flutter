import Flutter
import UIKit
import Photos // 👈 必须加这个

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

// 3. 视图类
class RecamNativeCameraView: NSObject, FlutterPlatformView, CameraViewControllerDelegate {
    
    private var _view: UIView
    private var _controller: CameraViewController
    private var _methodChannel: FlutterMethodChannel
    
    // 暂存 Flutter 的回调
    private var _takePhotoResult: FlutterResult?

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
             
        case "saveToGallery":
            if let args = call.arguments as? [String: Any],
               let path = args["path"] as? String {
                saveToAlbum(path: path, result: result)
            } else {
                result(FlutterError(code: "ARGS_ERROR", message: "Path is missing", details: nil))
            }

        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - 引擎回调
    func cameraViewController(_ controller: CameraViewController, didCapture image: UIImage) {
        print("✅ Swift: 引擎拍到了照片，准备写入磁盘...")
        
        let fileName = "recam_\(Int(Date().timeIntervalSince1970)).jpg"
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        DispatchQueue.global(qos: .background).async {
            do {
                if let data = image.jpegData(compressionQuality: 0.9) {
                    try data.write(to: fileURL)
                    print("💾 Swift: 已保存到临时目录 -> \(fileURL.path)")
                    
                    DispatchQueue.main.async {
                        if let callback = self._takePhotoResult {
                            callback(fileURL.path)
                            self._takePhotoResult = nil
                        }
                    }
                }
            } catch {
                print("❌ Swift Save Error: \(error)")
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
    
    // MARK: - 保存到系统相册 (修复了版本兼容性问题)
    private func saveToAlbum(path: String, result: @escaping FlutterResult) {
        PHPhotoLibrary.requestAuthorization { status in
            var isAuthorized = (status == .authorized)
            
            // 🚑 修复点：加了 #available 判断，只在 iOS 14+ 上检查 .limited
            if #available(iOS 14, *) {
                if status == .limited {
                    isAuthorized = true
                }
            }
            
            if isAuthorized {
                PHPhotoLibrary.shared().performChanges({
                    let url = URL(fileURLWithPath: path)
                    PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url)
                }) { success, error in
                    DispatchQueue.main.async {
                        if success {
                            print("💾 Swift: 系统相册保存成功！")
                            result(true)
                        } else {
                            print("❌ Swift: 系统相册保存失败 - \(String(describing: error))")
                            result(false)
                        }
                    }
                }
            } else {
                print("❌ Swift: 没有相册权限")
                DispatchQueue.main.async {
                    result(false)
                }
            }
        }
    }
}