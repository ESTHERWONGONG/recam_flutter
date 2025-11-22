import UIKit
import AVFoundation

protocol CameraViewControllerDelegate: AnyObject {
    func cameraViewController(_ controller: CameraViewController, didCapture image: UIImage)
    func cameraViewController(_ controller: CameraViewController, didFail error: Error)
    /// 实时 AI 推荐结果
    func cameraViewController(_ controller: CameraViewController, didUpdateLiveRecommendation result: AiRecommendResult)
}

class CameraViewController: UIViewController {

    weak var delegate: CameraViewControllerDelegate?

    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let videoQueue = DispatchQueue(label: "recam.video.queue")

    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var currentDevice: AVCaptureDevice?
    private var currentZoomFactor: CGFloat = 1.0
    private var currentPosition: AVCaptureDevice.Position = .back

    private var frameCount: Int = 0

    // 闪光灯模式（默认自动）
    private var flashMode: AVCaptureDevice.FlashMode = .auto

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        addGestures()
        configureSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    // MARK: - Session 配置

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                   for: .video,
                                                   position: currentPosition) else {
            delegate?.cameraViewController(self,
                                           didFail: NSError(domain: "Camera",
                                                            code: -1,
                                                            userInfo: [NSLocalizedDescriptionKey: "找不到相机设备"]))
            session.commitConfiguration()
            return
        }

        currentDevice = device

        // 基础 WB & 曝光
        do {
            try device.lockForConfiguration()

            if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                device.whiteBalanceMode = .continuousAutoWhiteBalance
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }

            device.unlockForConfiguration()
        } catch { }

        // 清空已有输入
        session.inputs.forEach { session.removeInput($0) }

        // 输入
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            }
        } catch {
            delegate?.cameraViewController(self, didFail: error)
            session.commitConfiguration()
            return
        }

        // 拍照输出
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }

        // 视频帧输出用于 AI
        if session.canAddOutput(videoOutput) {
            videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
            videoOutput.alwaysDiscardsLateVideoFrames = true
            session.addOutput(videoOutput)
        }

        // 预览层
        if previewLayer == nil {
            let layer = AVCaptureVideoPreviewLayer(session: session)
            layer.videoGravity = .resizeAspectFill
            view.layer.insertSublayer(layer, at: 0)
            previewLayer = layer
        } else {
            previewLayer?.session = session
        }

        session.commitConfiguration()
        if !session.isRunning {
            session.startRunning()
        }
    }

    // MARK: - 相机切换

    func switchCamera(isFront: Bool) {
        let targetPosition: AVCaptureDevice.Position = isFront ? .front : .back
        guard targetPosition != currentPosition else { return }

        currentPosition = targetPosition
        configureSession()
    }

    // MARK: - 拍照

    func capturePhoto() {
        let settings = AVCapturePhotoSettings()

        if photoOutput.supportedFlashModes.contains(flashMode) {
            settings.flashMode = flashMode
        } else {
            settings.flashMode = .off
        }

        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    // MARK: - 参数调节

    /// wbMode：0=Auto, 1=Warm, 2=Cool, 3=Cloudy
    func updateWhiteBalance(modeIndex: Int) {
        guard let device = currentDevice else { return }

        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }

            if modeIndex == 0 {
                if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                    device.whiteBalanceMode = .continuousAutoWhiteBalance
                }
                return
            }

            let temperature: Float
            switch modeIndex {
            case 1: temperature = 6500  // Warm
            case 2: temperature = 4000  // Cool
            case 3: temperature = 7500  // Cloudy
            default: temperature = 5000
            }

            let tint: Float = 0

            let tnt = AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(
                temperature: temperature,
                tint: tint
            )
            var gains = device.deviceWhiteBalanceGains(for: tnt)

            let maxGain = device.maxWhiteBalanceGain
            gains.redGain = max(1.0, min(gains.redGain, maxGain))
            gains.greenGain = max(1.0, min(gains.greenGain, maxGain))
            gains.blueGain = max(1.0, min(gains.blueGain, maxGain))

            if device.isWhiteBalanceModeSupported(.locked) {
                device.whiteBalanceMode = .locked
                device.setWhiteBalanceModeLocked(with: gains, completionHandler: nil)
            }

        } catch {
            delegate?.cameraViewController(self, didFail: error)
        }
    }

    /// 曝光补偿 EV（-2 ~ +2）
    func updateExposureBias(_ bias: Float) {
        guard let device = currentDevice else { return }

        do {
            try device.lockForConfiguration()
            let clamped = max(device.minExposureTargetBias,
                              min(bias, device.maxExposureTargetBias))
            device.setExposureTargetBias(clamped, completionHandler: nil)
            device.unlockForConfiguration()
        } catch {
            delegate?.cameraViewController(self, didFail: error)
        }
    }

    /// 闪光灯模式：0=关，1=自动，2=开
    func updateFlashMode(modeIndex: Int) {
        switch modeIndex {
        case 0: flashMode = .off
        case 2: flashMode = .on
        default: flashMode = .auto
        }
    }

    /// 设置离散焦距（0.5x / 1x / 2x）
    func setZoomFactor(_ factor: CGFloat) {
        guard let device = currentDevice else { return }

        let minZoom: CGFloat = 1.0
        let maxZoom = min(device.activeFormat.videoMaxZoomFactor, 5.0)
        var newZoom = factor
        newZoom = max(minZoom, min(newZoom, maxZoom))

        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = newZoom
            currentZoomFactor = newZoom
            device.unlockForConfiguration()
        } catch {
            delegate?.cameraViewController(self, didFail: error)
        }
    }

    // MARK: - 对焦 & 缩放手势

    private func addGestures() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTapToFocus(_:)))
        view.addGestureRecognizer(tap)

        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinchToZoom(_:)))
        view.addGestureRecognizer(pinch)
    }

    @objc private func handleTapToFocus(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: view)
        guard let device = currentDevice,
              let previewLayer = previewLayer else { return }

        let point = previewLayer.captureDevicePointConverted(fromLayerPoint: location)

        do {
            try device.lockForConfiguration()

            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = point
                device.focusMode = .continuousAutoFocus
            }

            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = point
                device.exposureMode = .continuousAutoExposure
            }

            device.unlockForConfiguration()
        } catch {
            delegate?.cameraViewController(self, didFail: error)
        }
    }

    @objc private func handlePinchToZoom(_ gesture: UIPinchGestureRecognizer) {
        guard let device = currentDevice else { return }

        switch gesture.state {
        case .began:
            currentZoomFactor = device.videoZoomFactor
        case .changed:
            let minZoom: CGFloat = 1.0
            let maxZoom = min(device.activeFormat.videoMaxZoomFactor, 5.0)
            var newZoom = currentZoomFactor * gesture.scale
            newZoom = max(minZoom, min(newZoom, maxZoom))

            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = newZoom
                device.unlockForConfiguration()
            } catch {
                delegate?.cameraViewController(self, didFail: error)
            }
        default:
            break
        }
    }
}

// MARK: - 拍照回调

extension CameraViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {

        if let error = error {
            delegate?.cameraViewController(self, didFail: error)
            return
        }

        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            delegate?.cameraViewController(
                self,
                didFail: NSError(domain: "Camera",
                                 code: -2,
                                 userInfo: [NSLocalizedDescriptionKey: "无法解析照片"])
            )
            return
        }

        delegate?.cameraViewController(self, didCapture: image)
    }
}

// MARK: - 实时预览 AI

extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {

        frameCount += 1
        guard frameCount % 10 == 0 else { return }

        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let ci = CIImage(cvImageBuffer: buffer)
        let ctx = CIContext()

        guard let cg = ctx.createCGImage(ci, from: ci.extent) else { return }

        let image = UIImage(cgImage: cg)

        let stats = HistogramAnalyzer.analyze(image: image)
        let result = AiRecommender().recommend(from: stats)

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.cameraViewController(self, didUpdateLiveRecommendation: result)
        }
    }
}
