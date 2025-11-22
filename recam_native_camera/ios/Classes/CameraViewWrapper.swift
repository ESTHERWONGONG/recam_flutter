import SwiftUI
import AVFoundation

struct CameraViewWrapper: UIViewControllerRepresentable {

    /// 每次 +1 就会触发拍照
    var captureID: Int

    /// 0=Auto, 1=Warm, 2=Cool, 3=Cloudy
    var wbMode: Int

    /// 曝光补偿 EV
    var exposureBias: Float

    /// 闪光灯模式：0=关，1=自动，2=开
    var flashModeIndex: Int

    /// 是否使用前置摄像头
    var isUsingFrontCamera: Bool

    /// 离散焦距（0.5 / 1 / 2）
    var zoomFactor: CGFloat

    /// 拍到照片后的回调（后面可以接预览页）
    var onPhotoCaptured: (UIImage) -> Void

    /// 出错时回调
    var onError: (Error) -> Void

    /// 实时 AI 推荐结果
    var onLiveRecommend: (AiRecommendResult) -> Void

    func makeUIViewController(context: Context) -> CameraViewController {
        let vc = CameraViewController()
        vc.delegate = context.coordinator

        // 初始设置一次
        vc.switchCamera(isFront: isUsingFrontCamera)
        vc.updateWhiteBalance(modeIndex: wbMode)
        vc.updateExposureBias(exposureBias)
        vc.updateFlashMode(modeIndex: flashModeIndex)
        vc.setZoomFactor(zoomFactor)

        return vc
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {
        // 摄像头前后
        if context.coordinator.lastIsUsingFrontCamera != isUsingFrontCamera {
            context.coordinator.lastIsUsingFrontCamera = isUsingFrontCamera
            uiViewController.switchCamera(isFront: isUsingFrontCamera)
        }

        // 拍照
        if context.coordinator.lastCaptureID != captureID {
            context.coordinator.lastCaptureID = captureID
            uiViewController.capturePhoto()
        }

        // 白平衡 & 曝光 & 闪光灯 & 焦距
        uiViewController.updateWhiteBalance(modeIndex: wbMode)
        uiViewController.updateExposureBias(exposureBias)
        uiViewController.updateFlashMode(modeIndex: flashModeIndex)
        uiViewController.setZoomFactor(zoomFactor)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, CameraViewControllerDelegate {
        var parent: CameraViewWrapper
        var lastCaptureID: Int = 0
        var lastIsUsingFrontCamera: Bool = false

        init(_ parent: CameraViewWrapper) {
            self.parent = parent
        }

        func cameraViewController(_ controller: CameraViewController, didCapture image: UIImage) {
            parent.onPhotoCaptured(image)
        }

        func cameraViewController(_ controller: CameraViewController, didFail error: Error) {
            parent.onError(error)
        }

        func cameraViewController(_ controller: CameraViewController,
                                  didUpdateLiveRecommendation result: AiRecommendResult) {
            parent.onLiveRecommend(result)
        }
    }
}

