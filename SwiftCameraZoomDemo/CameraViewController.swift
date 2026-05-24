import UIKit

final class CameraViewController: UIViewController {
    private enum Metrics {
        static let previewAspectRatio: CGFloat = 4.0 / 3.0
        static let previewTopInsetAfterSafeArea: CGFloat = 58
        static let minimumDockHeight: CGFloat = 132
        static let shutterSize: CGFloat = 78
        static let shutterTopInset: CGFloat = 38
        static let shutterBorderWidth: CGFloat = 5
        static let zoomButtonSize: CGFloat = 44
        static let zoomStackHeight: CGFloat = 44
        static let zoomStackBottomInsetInPreview: CGFloat = 25
        static let zoomButtonSpacing: CGFloat = 4
        static let zoomFontSize: CGFloat = 18
    }

    private let cameraManager = CameraSessionManager()

    private let bottomDockView = UIView()
    private let shutterButton = UIButton(type: .custom)
    private let zoomStackView = UIStackView()
    private let flashOverlayView = UIView()
    private let messageLabel = UILabel()

    private var zoomButtons: [UIButton] = []
    private let zoomOptions: [(title: String, factor: CGFloat)] = [
        (".5", 0.5),
        ("1x", 1.0),
        ("2", 2.0)
    ]
    private var selectedZoomFactor: CGFloat = 1.0
    private var pinchStartZoomFactor: CGFloat = 1.0

    override var prefersStatusBarHidden: Bool {
        true
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .black
        view.layer.addSublayer(cameraManager.previewLayer)

        configureCallbacks()
        configureDock()
        configureZoomControls()
        configureFlashOverlay()
        configureMessageLabel()
        configureGestures()

        cameraManager.requestAccessConfigureAndStart()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let desiredPreviewY = view.safeAreaInsets.top + Metrics.previewTopInsetAfterSafeArea
        let previewHeight = min(
            view.bounds.width * Metrics.previewAspectRatio,
            view.bounds.height - desiredPreviewY - Metrics.minimumDockHeight
        )
        let previewFrame = CGRect(
            x: 0,
            y: desiredPreviewY,
            width: view.bounds.width,
            height: previewHeight
        )
        cameraManager.previewLayer.frame = previewFrame

        let dockHeight = max(Metrics.minimumDockHeight, view.bounds.height - previewFrame.maxY)
        bottomDockView.frame = CGRect(
            x: 0,
            y: previewFrame.maxY,
            width: view.bounds.width,
            height: dockHeight
        )

        shutterButton.frame = CGRect(
            x: (bottomDockView.bounds.width - Metrics.shutterSize) / 2,
            y: Metrics.shutterTopInset,
            width: Metrics.shutterSize,
            height: Metrics.shutterSize
        )
        shutterButton.layer.cornerRadius = Metrics.shutterSize / 2

        let zoomSize = zoomStackView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        zoomStackView.frame = CGRect(
            x: (view.bounds.width - zoomSize.width) / 2,
            y: previewFrame.maxY - Metrics.zoomStackHeight - Metrics.zoomStackBottomInsetInPreview,
            width: zoomSize.width,
            height: Metrics.zoomStackHeight
        )

        flashOverlayView.frame = view.bounds
        messageLabel.frame = CGRect(
            x: 24,
            y: view.safeAreaInsets.top + 24,
            width: view.bounds.width - 48,
            height: 64
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        cameraManager.start()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cameraManager.stop()
    }

    private func configureCallbacks() {
        cameraManager.onAuthorizationDenied = { [weak self] in
            self?.showMessage("Camera access is required to run this demo.")
        }

        cameraManager.onConfigurationFailed = { [weak self] message in
            self?.showMessage(message)
        }

        cameraManager.onPhotoCaptured = { [weak self] in
            self?.showCaptureFlash()
        }

        cameraManager.onZoomChanged = { [weak self] displayZoomFactor in
            self?.updateZoomSelectionForCurrentZoom(displayZoomFactor)
        }
    }

    private func configureDock() {
        bottomDockView.backgroundColor = UIColor(white: 0.0, alpha: 0.98)
        view.addSubview(bottomDockView)

        shutterButton.backgroundColor = .white
        shutterButton.layer.cornerRadius = Metrics.shutterSize / 2
        shutterButton.layer.borderWidth = Metrics.shutterBorderWidth
        shutterButton.layer.borderColor = UIColor(white: 0.28, alpha: 1.0).cgColor
        shutterButton.layer.shadowColor = UIColor.black.cgColor
        shutterButton.layer.shadowOpacity = 0.32
        shutterButton.layer.shadowRadius = 10
        shutterButton.layer.shadowOffset = CGSize(width: 0, height: 3)
        shutterButton.addTarget(self, action: #selector(handleShutterTap), for: .touchUpInside)
        shutterButton.addTarget(self, action: #selector(handleShutterPressDown), for: .touchDown)
        shutterButton.addTarget(self, action: #selector(handleShutterPressCancel), for: [.touchCancel, .touchDragExit, .touchUpInside, .touchUpOutside])
        shutterButton.accessibilityLabel = "Capture photo"
        bottomDockView.addSubview(shutterButton)
    }

    private func configureZoomControls() {
        zoomStackView.axis = .horizontal
        zoomStackView.alignment = .center
        zoomStackView.spacing = Metrics.zoomButtonSpacing
        view.addSubview(zoomStackView)

        zoomButtons = zoomOptions.map { option in
            let button = UIButton(type: .custom)
            button.setTitle(option.title, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: Metrics.zoomFontSize, weight: .medium)
            button.titleLabel?.adjustsFontSizeToFitWidth = true
            button.titleLabel?.minimumScaleFactor = 0.8
            button.tag = Int(option.factor * 10)
            button.widthAnchor.constraint(equalToConstant: Metrics.zoomButtonSize).isActive = true
            button.heightAnchor.constraint(equalToConstant: Metrics.zoomButtonSize).isActive = true
            button.layer.cornerRadius = Metrics.zoomButtonSize / 2
            button.addTarget(self, action: #selector(handleZoomTap(_:)), for: .touchUpInside)
            button.accessibilityLabel = "\(option.title) zoom"
            zoomStackView.addArrangedSubview(button)
            return button
        }

        updateZoomSelection(to: selectedZoomFactor)
    }

    private func configureFlashOverlay() {
        flashOverlayView.backgroundColor = .white
        flashOverlayView.alpha = 0
        flashOverlayView.isUserInteractionEnabled = false
        view.addSubview(flashOverlayView)
    }

    private func configureMessageLabel() {
        messageLabel.alpha = 0
        messageLabel.numberOfLines = 2
        messageLabel.textAlignment = .center
        messageLabel.textColor = .white
        messageLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        messageLabel.backgroundColor = UIColor.black.withAlphaComponent(0.62)
        messageLabel.layer.cornerRadius = 14
        messageLabel.clipsToBounds = true
        view.addSubview(messageLabel)
    }

    private func configureGestures() {
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        view.addGestureRecognizer(pinchGesture)
    }

    private func updateZoomSelection(to factor: CGFloat) {
        selectedZoomFactor = factor

        for (index, option) in zoomOptions.enumerated() {
            let button = zoomButtons[index]
            let isSelected = option.factor == factor
            button.backgroundColor = isSelected ? UIColor(white: 0.22, alpha: 0.84) : .clear
            button.setTitleColor(isSelected ? UIColor(red: 1.0, green: 0.78, blue: 0.12, alpha: 1.0) : .white, for: .normal)
            button.layer.shadowColor = UIColor.black.cgColor
            button.layer.shadowOpacity = isSelected ? 0.22 : 0.5
            button.layer.shadowRadius = isSelected ? 6 : 2
            button.layer.shadowOffset = CGSize(width: 0, height: 1)
        }
    }

    private func updateZoomSelectionForCurrentZoom(_ currentZoomFactor: CGFloat) {
        guard let nearestOption = zoomOptions.min(by: {
            abs($0.factor - currentZoomFactor) < abs($1.factor - currentZoomFactor)
        }) else {
            return
        }

        updateZoomSelection(to: nearestOption.factor)
    }

    private func showCaptureFlash() {
        flashOverlayView.alpha = 0.85
        UIView.animate(withDuration: 0.22) {
            self.flashOverlayView.alpha = 0
        }
    }

    private func showMessage(_ message: String) {
        messageLabel.text = message
        messageLabel.alpha = 1
    }

    @objc private func handleShutterTap() {
        cameraManager.capturePhoto()
    }

    @objc private func handleShutterPressDown() {
        UIView.animate(withDuration: 0.08) {
            self.shutterButton.transform = CGAffineTransform(scaleX: 0.94, y: 0.94)
        }
    }

    @objc private func handleShutterPressCancel() {
        UIView.animate(withDuration: 0.12) {
            self.shutterButton.transform = .identity
        }
    }

    @objc private func handleZoomTap(_ sender: UIButton) {
        let factor = CGFloat(sender.tag) / 10.0
        updateZoomSelection(to: factor)
        cameraManager.setDisplayZoomFactor(factor, smooth: true)
    }

    @objc private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
        switch recognizer.state {
        case .began:
            pinchStartZoomFactor = cameraManager.currentRawZoomFactor()

        case .changed:
            let targetZoom = pinchStartZoomFactor * recognizer.scale
            cameraManager.setRawZoomFactor(targetZoom, smooth: false)

        default:
            break
        }
    }
}
