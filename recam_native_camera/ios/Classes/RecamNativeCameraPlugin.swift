import Flutter
import UIKit
import AVFoundation

public class RecamNativeCameraPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {

    // 方法通道（给 Dart 调用）
    private var methodChannel: FlutterMethodChannel?

    // 事件通道（给 Dart 发送 AI 推荐等信息）
    private var eventSink: FlutterEventSink?

    public static func register(with registrar: FlutterPluginRegistrar) {
        // ⚠️ 通道名要和 Dart 里的完全一致：
        // MethodChannel('recam_native_camera/methods')
        let methodChannel = FlutterMethodChannel(
            name: "recam_native_camera/methods",
            binaryMessenger: registrar.messenger()
        )

        // EventChannel('recam_native_camera/ai_stream')
        let eventChannel = FlutterEventChannel(
            name: "recam_native_camera/ai_stream",
            binaryMessenger: registrar.messenger()
        )

        let instance = RecamNativeCameraPlugin()
        instance.methodChannel = methodChannel

        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        eventChannel.setStreamHandler(instance)
    }

    // MARK: - FlutterPlugin

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {

        case "takePhoto":
            takePhoto(result: result)

        case "switchCamera":
            switchCamera(result: result)

        case "setAspectRatio":
            if let args = call.arguments as? [String: Any],
               let aspect = args["aspect"] as? String {
                setAspectRatio(aspect: aspect, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGS",
                                    message: "Missing aspect",
                                    details: nil))
            }

        case "setFlashMode":
            if let args = call.arguments as? [String: Any],
               let mode = args["mode"] as? String {
                setFlashMode(mode: mode, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGS",
                                    message: "Missing flash mode",
                                    details: nil))
            }

        case "setQuality":
            if let args = call.arguments as? [String: Any],
               let quality = args["quality"] as? String {
                setQuality(quality: quality, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGS",
                                    message: "Missing quality",
                                    details: nil))
            }

        // 预留一个基础测试方法
        case "getPlatformVersion":
            result("iOS " + UIDevice.current.systemVersion)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - FlutterStreamHandler（AI 事件通道）

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        print("AI event stream onListen")
        // 现在先不推数据，未来在这里发送 AI 推荐
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        print("AI event stream onCancel")
        return nil
    }

    // MARK: - 相机相关（先空实现，保证不崩）

    private func takePhoto(result: FlutterResult) {
        print("takePhoto() called (stub)")
        // TODO: 这里以后接真实拍照逻辑，并返回图片路径
        result("") // 现在 Dart 那边会拿到空字符串
    }

    private func switchCamera(result: FlutterResult) {
        print("switchCamera() called (stub)")
        result(nil)
    }

    private func setAspectRatio(aspect: String, result: FlutterResult) {
        print("setAspectRatio() called with aspect = \(aspect)")
        result(nil)
    }

    private func setFlashMode(mode: String, result: FlutterResult) {
        print("setFlashMode() called with mode = \(mode)")
        result(nil)
    }

    private func setQuality(quality: String, result: FlutterResult) {
        print("setQuality() called with quality = \(quality)")
        result(nil)
    }
}
