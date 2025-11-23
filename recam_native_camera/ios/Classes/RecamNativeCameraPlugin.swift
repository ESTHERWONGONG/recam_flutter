import Flutter
import UIKit
import Photos

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

class RecamNativeCameraView: NSObject, FlutterPlatformView, CameraViewControllerDelegate {
    private var _view: UIView
    private var _controller: CameraViewController
    private var _methodChannel: FlutterMethodChannel
    
    // 暂存回调
    private var _takePhotoResult: FlutterResult?
    // 暂存当前拍照想要的比例 (默认修正为 4:3)
    private var _currentRatio: String = "4:3"

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
            // 1. 接收参数：这次拍照要什么比例？
            if let args = call.arguments as? [String: Any],
               let ratio = args["ratio"] as? String {
                _currentRatio = ratio
            } else {
                _currentRatio = "4:3" // 默认
            }
            
            _takePhotoResult = result
            print("📸 Swift: 收到拍照请求，目标比例: \(_currentRatio)")
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
            if let args = call.arguments as? [String: Any], let path = args["path"] as? String {
                saveToAlbum(path: path, result: result)
            } else {
                result(FlutterError(code: "ARGS_ERROR", message: "Path missing", details: nil))
            }

        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - 引擎回调 (🔴 核心修改：存到 Documents 目录)
    func cameraViewController(_ controller: CameraViewController, didCapture image: UIImage) {
        print("✅ Swift: 拍到原始照片 \(image.size)，准备处理...")
        
        DispatchQueue.global(qos: .userInitiated).async {
            // 1. 根据比例裁剪图片
            var finalImage = image
            if self._currentRatio == "1:1" {
                finalImage = self.cropToSquare(image: image)
                print("✂️ 已裁剪为 1:1，新尺寸: \(finalImage.size)")
            }
            
            // 2. ✅ [修改] 获取 App 文档目录 (永久存储，解决红X问题)
            let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            let docDir = paths[0]
            
            let fileName = "recam_\(Int(Date().timeIntervalSince1970)).jpg"
            let fileURL = docDir.appendingPathComponent(fileName)
            
            do {
                if let data = finalImage.jpegData(compressionQuality: 0.9) {
                    try data.write(to: fileURL)
                    print("💾 Swift: 已永久保存 -> \(fileURL.path)")
                    
                    DispatchQueue.main.async {
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
    
    // ✂️ 裁剪算法：把长方形切成正方形 (取中间)
    private func cropToSquare(image: UIImage) -> UIImage {
        let originalWidth  = CGFloat(image.size.width)
        let originalHeight = CGFloat(image.size.height)
        let edge = min(originalWidth, originalHeight)
        
        let posX = (originalWidth - edge) / 2.0
        let posY = (originalHeight - edge) / 2.0
        
        let cropSquare = CGRect(x: posX, y: posY, width: edge, height: edge)
        
        // 修正图片方向 (Fix Orientation)
        guard let imageRef = image.cgImage?.cropping(to: cropSquare) else { return image }
        return UIImage(cgImage: imageRef, scale: image.scale, orientation: image.imageOrientation)
    }
    
    func cameraViewController(_ controller: CameraViewController, didFail error: Error) {
        _takePhotoResult?(FlutterError(code: "CAMERA_ERROR", message: error.localizedDescription, details: nil))
        _takePhotoResult = nil
    }
    
    func cameraViewController(_ controller: CameraViewController, didUpdateLiveRecommendation result: AiRecommendResult) {
        guard let sink = RecamNativeCameraPlugin.aiEventSink else { return }
        sink(["filmId": result.preset.id, "message": result.debugText])
    }
    
    private func saveToAlbum(path: String, result: @escaping FlutterResult) {
        PHPhotoLibrary.requestAuthorization { status in
            var isAuthorized = (status == .authorized)
            if #available(iOS 14, *) { if status == .limited { isAuthorized = true } }
            
            if isAuthorized {
                PHPhotoLibrary.shared().performChanges({
                    let url = URL(fileURLWithPath: path)
                    PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url)
                }) { success, error in
                    DispatchQueue.main.async {
                        result(success)
                    }
                }
            } else {
                DispatchQueue.main.async { result(false) }
            }
        }
    }
}