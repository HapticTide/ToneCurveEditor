//
//  ViewController.swift
//  ToneCurveEditor
//
//  Created by Sun on 2026/02/10.
//

import CoreImage
import PhotosUI
import ToneCurveEditor
import UIKit

final class ViewController: UIViewController {
    private let previewView = PreviewView()
    private let channelSelectorView = ChannelSelectorView()
    private let editorView = ToneCurveEditorView()
    private let presetLabel = UILabel()
    private let presetSegmentedControl = UISegmentedControl(items: DemoPreset.allCases.map(\.title))
    private let dragFeelLabel = UILabel()
    private let dragFeelSegmentedControl = UISegmentedControl(items: DragFeelPreset.allCases.map(\.title))
    private let statusLabel = UILabel()
    private let loadImageNavButton = UIButton(type: .system)

    private let pickerCoordinator = ImagePickerCoordinator()
    private let displayContext = CIContext(options: nil)
    private let renderEngine: ToneCurveRenderEngine?

    private var inputImage: UIImage?
    private var inputCIImage: CIImage?
    private var interactivePreviewCIImage: CIImage?
    private var renderTask: Task<Void, Never>?
    private var interactiveRenderScheduledTask: Task<Void, Never>?
    private var isDraggingCurve = false
    private var lastInteractiveRenderUptime: TimeInterval = 0

    private let interactiveRenderFPS: Double = 30
    private let interactivePreviewMaxDimension: CGFloat = 1600

    init() {
        renderEngine = try? ToneCurveRenderEngine(backendPreference: .metalPreferred)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        renderEngine = try? ToneCurveRenderEngine(backendPreference: .metalPreferred)
        super.init(coder: coder)
    }

    deinit {
        renderTask?.cancel()
        interactiveRenderScheduledTask?.cancel()
    }
}

private extension ViewController {
    enum DemoPreset: Int, CaseIterable {
        case linear
        case sCurve
        case fade
        case highContrast

        var title: String {
            switch self {
            case .linear:
                "Linear"
            case .sCurve:
                "S-Curve"
            case .fade:
                "Fade"
            case .highContrast:
                "Contrast+"
            }
        }

        func curveSet() -> ToneCurveSet {
            switch self {
            case .linear:
                .identity
            case .sCurve:
                ToneCurveSet(master: Self.curve([
                    .init(x: 0, y: 0),
                    .init(x: 0.2, y: 0.12),
                    .init(x: 0.5, y: 0.5),
                    .init(x: 0.8, y: 0.88),
                    .init(x: 1, y: 1),
                ]))
            case .fade:
                ToneCurveSet(master: Self.curve([
                    .init(x: 0, y: 0.1),
                    .init(x: 0.25, y: 0.3),
                    .init(x: 0.5, y: 0.58),
                    .init(x: 0.75, y: 0.82),
                    .init(x: 1, y: 1),
                ]))
            case .highContrast:
                ToneCurveSet(master: Self.curve([
                    .init(x: 0, y: 0),
                    .init(x: 0.2, y: 0.05),
                    .init(x: 0.5, y: 0.52),
                    .init(x: 0.8, y: 0.95),
                    .init(x: 1, y: 1),
                ]))
            }
        }

        private static func curve(_ points: [ToneCurvePoint]) -> ToneCurve {
            (try? ToneCurve(points: points)) ?? .linear
        }
    }

    enum DragFeelPreset: Int, CaseIterable {
        case precision
        case easy

        var title: String {
            switch self {
            case .precision:
                "Precision"
            case .easy:
                "Easy"
            }
        }

        var editorPreset: ToneCurveEditorDragPreset {
            switch self {
            case .precision:
                .precision
            case .easy:
                .easy
            }
        }
    }
}

extension ViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "ToneCurveEditor Demo"

        setupUI()
        setupActions()
        setupInitialState()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isMovingFromParent || isBeingDismissed {
            isDraggingCurve = false
            renderTask?.cancel()
            interactiveRenderScheduledTask?.cancel()
        }
    }
}

private extension ViewController {
    func setupUI() {
        presetLabel.text = "Preset"
        presetLabel.font = .preferredFont(forTextStyle: .headline)

        let presetStack = UIStackView(arrangedSubviews: [presetLabel, presetSegmentedControl])
        presetStack.axis = .vertical
        presetStack.spacing = 8

        dragFeelLabel.text = "Drag Feel"
        dragFeelLabel.font = .preferredFont(forTextStyle: .headline)

        let dragFeelStack = UIStackView(arrangedSubviews: [dragFeelLabel, dragFeelSegmentedControl])
        dragFeelStack.axis = .horizontal
        dragFeelStack.spacing = 8

        let editorSectionLabel = UILabel()
        editorSectionLabel.text = "Curve Editor"
        editorSectionLabel.font = .preferredFont(forTextStyle: .headline)

        statusLabel.font = .preferredFont(forTextStyle: .footnote)
        statusLabel.textColor = .secondaryLabel

        editorView.backgroundColor = UIColor(red: 0.14, green: 0.15, blue: 0.18, alpha: 0.2)
        editorView.layer.cornerRadius = 12
        editorView.layer.masksToBounds = true

        let editorRow = UIStackView(arrangedSubviews: [channelSelectorView, editorView])
        editorRow.axis = .horizontal
        editorRow.spacing = 8
        editorRow.alignment = .fill
        channelSelectorView.widthAnchor.constraint(equalToConstant: 44).isActive = true
        channelSelectorView.setContentHuggingPriority(.required, for: .vertical)
        channelSelectorView.setContentCompressionResistancePriority(.required, for: .vertical)

        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        let stack = UIStackView(arrangedSubviews: [
            previewView,
            editorSectionLabel,
            editorRow,
            presetStack,
            dragFeelStack,
            statusLabel,
        ])
        stack.axis = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -16),
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32),

            previewView.heightAnchor.constraint(equalToConstant: 220),
            editorView.heightAnchor.constraint(equalToConstant: 260),
        ])
    }

    func setupActions() {
        var loadImageConfig = UIButton.Configuration.filled()
        loadImageConfig.title = "Load Image"
        loadImageConfig.baseBackgroundColor = .systemBlue
        loadImageConfig.baseForegroundColor = .white
        loadImageConfig.cornerStyle = .capsule
        loadImageConfig.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
        loadImageNavButton.configuration = loadImageConfig
        loadImageNavButton.addTarget(self, action: #selector(loadImageTapped), for: .touchUpInside)
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: loadImageNavButton)
        presetSegmentedControl.addTarget(self, action: #selector(presetChanged), for: .valueChanged)
        dragFeelSegmentedControl.addTarget(self, action: #selector(dragFeelChanged), for: .valueChanged)
        editorView.addTarget(self, action: #selector(curveValueChanged), for: .valueChanged)
        editorView.addTarget(self, action: #selector(curveEditingDidBegin), for: .editingDidBegin)
        editorView.addTarget(self, action: #selector(curveEditingDidEnd), for: .editingDidEnd)

        channelSelectorView.onChannelChanged = { [weak self] channel in
            self?.editorView.activeChannel = channel
        }
        channelSelectorView.onResetTapped = { [weak self] in
            self?.resetTapped()
        }

        pickerCoordinator.onImagePicked = { [weak self] image in
            self?.applyPickedImage(image)
        }
    }

    func setupInitialState() {
        presetSegmentedControl.selectedSegmentIndex = DemoPreset.linear.rawValue
        editorView.curveSet = .identity
        editorView.activeChannel = .master
        editorView.lockEndpoints = true
        dragFeelSegmentedControl.selectedSegmentIndex = DragFeelPreset.easy.rawValue
        applyDragFeelPreset(.easy)
        statusLabel.text = "Load an image to begin."
    }

    func applyDragFeelPreset(_ preset: DragFeelPreset) {
        editorView.dragInteractionPreset = preset.editorPreset
    }

    func applyPickedImage(_ image: UIImage) {
        inputImage = image
        inputCIImage = makeCIImage(from: image)
        interactivePreviewCIImage = makeInteractivePreviewCIImage(from: inputCIImage)
        previewView.originalImage = image
        previewView.processedImage = image
        renderCurrentImage(quality: .full)
    }

    func renderCurrentImage(quality: RenderQuality) {
        let sourceImage: CIImage?
        switch quality {
        case .interactive:
            sourceImage = interactivePreviewCIImage ?? inputCIImage
        case .full:
            sourceImage = inputCIImage
        }

        guard let sourceImage else {
            return
        }

        guard let renderEngine else {
            statusLabel.text = "Renderer unavailable."
            previewView.processedImage = inputImage
            return
        }

        let curveSet = editorView.curveSet
        renderTask?.cancel()
        if quality == .full {
            statusLabel.text = "Rendering..."
        }

        renderTask = Task { [weak self] in
            guard let self else {
                return
            }

            do {
                let outputCIImage = try await renderEngine.render(image: sourceImage, curveSet: curveSet)
                try Task.checkCancellation()

                guard let cgImage = displayContext.createCGImage(outputCIImage, from: outputCIImage.extent) else {
                    await MainActor.run {
                        self.statusLabel.text = "Render failed: createCGImage returned nil."
                    }
                    return
                }

                let renderedImage = UIImage(cgImage: cgImage)
                await MainActor.run {
                    self.previewView.processedImage = renderedImage
                    if quality == .full {
                        self.statusLabel.text = "Rendered using \(self.renderEngineStatusText())."
                    }
                }
            } catch is CancellationError {
                return
            } catch {
                await MainActor.run {
                    self.statusLabel.text = "Render failed: \(error.localizedDescription)"
                }
            }
        }
    }

    func renderEngineStatusText() -> String {
        guard let renderEngine else {
            return "Unavailable"
        }
        return renderEngine.usingMetal ? "Metal" : "CIColorCube fallback"
    }

    func makeCIImage(from image: UIImage) -> CIImage? {
        CIImage(image: image) ?? image.ciImage ?? image.cgImage.map { CIImage(cgImage: $0) }
    }

    func makeInteractivePreviewCIImage(from sourceImage: CIImage?) -> CIImage? {
        guard let sourceImage else {
            return nil
        }

        let extent = sourceImage.extent.integral
        let longest = max(extent.width, extent.height)
        guard longest > 0 else {
            return sourceImage
        }

        let scale = min(1, interactivePreviewMaxDimension / longest)
        guard scale < 0.999 else {
            return sourceImage
        }

        let filter = CIFilter(name: "CILanczosScaleTransform")
        filter?.setValue(sourceImage, forKey: kCIInputImageKey)
        filter?.setValue(scale, forKey: kCIInputScaleKey)
        filter?.setValue(1.0, forKey: kCIInputAspectRatioKey)
        guard let scaledOutput = filter?.outputImage else {
            return sourceImage
        }
        let scaled = scaledOutput.cropped(to: scaledOutput.extent.integral)

        guard let cgImage = displayContext.createCGImage(scaled, from: scaled.extent) else {
            return scaled
        }

        return CIImage(cgImage: cgImage)
    }

    func scheduleInteractiveRender() {
        guard isDraggingCurve else {
            renderCurrentImage(quality: .full)
            return
        }

        let now = ProcessInfo.processInfo.systemUptime
        let minInterval = 1 / interactiveRenderFPS
        let elapsed = now - lastInteractiveRenderUptime

        if elapsed >= minInterval {
            lastInteractiveRenderUptime = now
            renderCurrentImage(quality: .interactive)
            return
        }

        interactiveRenderScheduledTask?.cancel()
        let delay = max(0, minInterval - elapsed)
        interactiveRenderScheduledTask = Task { [weak self] in
            let delayNanos = UInt64(delay * 1_000_000_000)
            try? await Task.sleep(nanoseconds: delayNanos)
            guard let self, !Task.isCancelled, self.isDraggingCurve else {
                return
            }
            self.lastInteractiveRenderUptime = ProcessInfo.processInfo.systemUptime
            self.renderCurrentImage(quality: .interactive)
        }
    }

    enum RenderQuality {
        case interactive
        case full
    }
}

private extension ViewController {
    @objc
    func loadImageTapped() {
        pickerCoordinator.presentPicker(from: self)
    }

    @objc
    func resetTapped() {
        presetSegmentedControl.selectedSegmentIndex = DemoPreset.linear.rawValue
        editorView.curveSet = ToneCurveSet.identity
        channelSelectorView.selectedChannel = .master
        editorView.activeChannel = .master
        renderCurrentImage(quality: .full)
    }

    @objc
    func presetChanged() {
        guard let preset = DemoPreset(rawValue: presetSegmentedControl.selectedSegmentIndex) else {
            return
        }
        editorView.curveSet = preset.curveSet()
        renderCurrentImage(quality: .full)
    }

    @objc
    func dragFeelChanged() {
        guard let preset = DragFeelPreset(rawValue: dragFeelSegmentedControl.selectedSegmentIndex) else {
            return
        }
        applyDragFeelPreset(preset)
    }

    @objc
    func curveValueChanged() {
        if presetSegmentedControl.selectedSegmentIndex != UISegmentedControl.noSegment {
            presetSegmentedControl.selectedSegmentIndex = UISegmentedControl.noSegment
        }
        scheduleInteractiveRender()
    }

    @objc
    func curveEditingDidBegin() {
        isDraggingCurve = true
        interactiveRenderScheduledTask?.cancel()
        statusLabel.text = "Rendering preview..."
    }

    @objc
    func curveEditingDidEnd() {
        isDraggingCurve = false
        interactiveRenderScheduledTask?.cancel()
        renderCurrentImage(quality: .full)
    }
}
