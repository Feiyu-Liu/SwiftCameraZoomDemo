import AVFoundation
import UIKit

final class CameraSessionManager: NSObject {
    let session = AVCaptureSession()
    let previewLayer: AVCaptureVideoPreviewLayer

    var onAuthorizationDenied: (() -> Void)?
    var onConfigurationFailed: ((String) -> Void)?
    var onPhotoCaptured: (() -> Void)?
    var onZoomChanged: ((CGFloat) -> Void)?

    private let sessionQueue = DispatchQueue(label: "com.tilapia.camera.session")
    private let photoOutput = AVCapturePhotoOutput()

    private var videoInput: AVCaptureDeviceInput?
    private var currentVideoDevice: AVCaptureDevice?
    private var isConfigured = false
    private let uiMaxZoomFactor: CGFloat = 10.0
    private let cameraAppStyleZoomRampRate: Float = 5.0

    override init() {
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        super.init()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRuntimeError(_:)),
            name: .AVCaptureSessionRuntimeError,
            object: session
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func requestAccessConfigureAndStart() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndStart()

        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self else { return }
                if granted {
                    self.configureAndStart()
                } else {
                    DispatchQueue.main.async {
                        self.onAuthorizationDenied?()
                    }
                }
            }

        case .denied, .restricted:
            DispatchQueue.main.async {
                self.onAuthorizationDenied?()
            }

        @unknown default:
            DispatchQueue.main.async {
                self.onAuthorizationDenied?()
            }
        }
    }

    func start() {
        sessionQueue.async {
            guard self.isConfigured, !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    func stop() {
        sessionQueue.async {
            guard self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    func capturePhoto() {
        sessionQueue.async {
            guard self.isConfigured else { return }
            let settings = AVCapturePhotoSettings()
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    func currentRawZoomFactor() -> CGFloat {
        currentVideoDevice?.videoZoomFactor ?? 1.0
    }

    func setDisplayZoomFactor(_ displayFactor: CGFloat, smooth: Bool) {
        sessionQueue.async {
            guard let device = self.currentVideoDevice else { return }
            let rawFactor = self.rawZoomFactor(forDisplayZoom: displayFactor, device: device)
            self.setRawZoomFactor(rawFactor, on: device, smooth: smooth)
        }
    }

    func setRawZoomFactor(_ rawFactor: CGFloat, smooth: Bool) {
        sessionQueue.async {
            guard let device = self.currentVideoDevice else { return }
            self.setRawZoomFactor(rawFactor, on: device, smooth: smooth)
        }
    }

    private func configureAndStart() {
        sessionQueue.async {
            if self.isConfigured {
                if !self.session.isRunning {
                    self.session.startRunning()
                }
                return
            }

            self.session.beginConfiguration()
            self.session.sessionPreset = .photo

            do {
                guard let device = Self.preferredVideoDevice(position: .back) else {
                    throw CameraSetupError.noCamera
                }

                let input = try AVCaptureDeviceInput(device: device)
                guard self.session.canAddInput(input) else {
                    throw CameraSetupError.cannotAddInput
                }

                self.session.addInput(input)
                self.videoInput = input
                self.currentVideoDevice = device

                guard self.session.canAddOutput(self.photoOutput) else {
                    throw CameraSetupError.cannotAddOutput
                }

                self.session.addOutput(self.photoOutput)
                self.isConfigured = true
                self.session.commitConfiguration()
                self.notifyZoomChanged(rawZoomFactor: device.videoZoomFactor, on: device)
                self.session.startRunning()
            } catch {
                self.session.commitConfiguration()
                DispatchQueue.main.async {
                    self.onConfigurationFailed?(error.localizedDescription)
                }
            }
        }
    }

    private static func preferredVideoDevice(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let deviceTypes: [AVCaptureDevice.DeviceType]

        switch position {
        case .back:
            deviceTypes = [
                .builtInTripleCamera,
                .builtInDualWideCamera,
                .builtInDualCamera,
                .builtInWideAngleCamera
            ]

        case .front:
            deviceTypes = [
                .builtInTrueDepthCamera,
                .builtInWideAngleCamera
            ]

        default:
            deviceTypes = [.builtInWideAngleCamera]
        }

        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: position
        )

        return discoverySession.devices.first
    }

    private func rawZoomFactor(forDisplayZoom displayFactor: CGFloat, device: AVCaptureDevice) -> CGFloat {
        if #available(iOS 18.0, *) {
            let multiplier = max(device.displayVideoZoomFactorMultiplier, 0.0001)
            return displayFactor / multiplier
        } else {
            return displayFactor
        }
    }

    private func displayZoomFactor(forRawZoom rawFactor: CGFloat, device: AVCaptureDevice) -> CGFloat {
        if #available(iOS 18.0, *) {
            return rawFactor * device.displayVideoZoomFactorMultiplier
        } else {
            return rawFactor
        }
    }

    private func setRawZoomFactor(_ rawFactor: CGFloat, on device: AVCaptureDevice, smooth: Bool) {
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }

            let minZoom = device.minAvailableVideoZoomFactor
            let maxZoom = min(device.maxAvailableVideoZoomFactor, uiMaxZoomFactor)
            let clampedZoom = min(max(rawFactor, minZoom), maxZoom)

            if smooth {
                device.ramp(toVideoZoomFactor: clampedZoom, withRate: cameraAppStyleZoomRampRate)
            } else {
                device.videoZoomFactor = clampedZoom
            }

            notifyZoomChanged(rawZoomFactor: clampedZoom, on: device)
        } catch {
            DispatchQueue.main.async {
                self.onConfigurationFailed?(error.localizedDescription)
            }
        }
    }

    private func notifyZoomChanged(rawZoomFactor: CGFloat, on device: AVCaptureDevice) {
        let displayZoom = displayZoomFactor(forRawZoom: rawZoomFactor, device: device)
        DispatchQueue.main.async {
            self.onZoomChanged?(displayZoom)
        }
    }

    @objc private func handleRuntimeError(_ notification: Notification) {
        let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError
        DispatchQueue.main.async {
            self.onConfigurationFailed?(error?.localizedDescription ?? "Camera session runtime error.")
        }
    }
}

extension CameraSessionManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        DispatchQueue.main.async {
            if let error {
                self.onConfigurationFailed?(error.localizedDescription)
            } else {
                self.onPhotoCaptured?()
            }
        }
    }
}

private enum CameraSetupError: LocalizedError {
    case noCamera
    case cannotAddInput
    case cannotAddOutput

    var errorDescription: String? {
        switch self {
        case .noCamera:
            return "No back camera is available."
        case .cannotAddInput:
            return "Cannot add the selected camera input."
        case .cannotAddOutput:
            return "Cannot add photo output."
        }
    }
}
