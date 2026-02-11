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
    private let interactiveRenderEngine: ToneCurveRenderEngine?

    private var inputImage: UIImage?
    private var inputCIImage: CIImage?
    private var interactivePreviewCIImage: CIImage?
    private var fullRenderTask: Task<Void, Never>?
    private var interactiveRenderTask: Task<Void, Never>?
    private var isDraggingCurve = false
    private var interactiveRenderInFlight = false
    private var interactiveRenderPending = false
    private var pendingInteractiveCurveSet: ToneCurveSet?

    private let interactivePreviewMaxDimension: CGFloat = 960

    init() {
        renderEngine = try? ToneCurveRenderEngine(
            backendPreference: .metalPreferred,
            lutResolution: 1024,
            cubeDimension: 64
        )
        interactiveRenderEngine = try? ToneCurveRenderEngine(
            backendPreference: .metalPreferred,
            lutResolution: 256,
            cubeDimension: 32
        )
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        renderEngine = try? ToneCurveRenderEngine(
            backendPreference: .metalPreferred,
            lutResolution: 1024,
            cubeDimension: 64
        )
        interactiveRenderEngine = try? ToneCurveRenderEngine(
            backendPreference: .metalPreferred,
            lutResolution: 256,
            cubeDimension: 32
        )
        super.init(coder: coder)
    }

    deinit {
        fullRenderTask?.cancel()
        interactiveRenderTask?.cancel()
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
            interactiveRenderInFlight = false
            interactiveRenderPending = false
            pendingInteractiveCurveSet = nil
            fullRenderTask?.cancel()
            interactiveRenderTask?.cancel()
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
        previewView.processedCIImage = nil
        previewView.processedImage = image
        previewView.processedCIImage = inputCIImage
        renderCurrentImage(quality: .full)
    }

    func renderCurrentImage(
        quality: RenderQuality,
        curveSetOverride: ToneCurveSet? = nil,
        completion: (() -> Void)? = nil
    ) {
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

        let activeEngine: ToneCurveRenderEngine?
        switch quality {
        case .interactive:
            activeEngine = interactiveRenderEngine ?? renderEngine
        case .full:
            activeEngine = renderEngine ?? interactiveRenderEngine
        }

        guard let activeEngine else {
            statusLabel.text = "Renderer unavailable."
            previewView.processedImage = inputImage
            previewView.processedCIImage = inputCIImage
            return
        }

        let curveSet = curveSetOverride ?? editorView.curveSet
        if quality == .full {
            fullRenderTask?.cancel()
        } else {
            interactiveRenderTask?.cancel()
        }
        if quality == .full {
            statusLabel.text = "Rendering..."
        }

        let task = Task { [weak self] in
            defer {
                if let completion {
                    Task { @MainActor in
                        completion()
                    }
                }
            }
            guard let self else {
                return
            }

            do {
                let outputCIImage = try await activeEngine.render(image: sourceImage, curveSet: curveSet)
                try Task.checkCancellation()

                await MainActor.run {
                    self.previewView.processedCIImage = outputCIImage
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

        if quality == .full {
            fullRenderTask = task
        } else {
            interactiveRenderTask = task
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
            interactiveRenderPending = false
            pendingInteractiveCurveSet = nil
            renderCurrentImage(quality: .full)
            return
        }

        interactiveRenderPending = true
        startInteractiveRenderIfNeeded()
    }

    @MainActor
    func startInteractiveRenderIfNeeded() {
        guard isDraggingCurve, interactiveRenderPending, !interactiveRenderInFlight else {
            return
        }

        interactiveRenderPending = false
        interactiveRenderInFlight = true
        let curveSet = pendingInteractiveCurveSet ?? editorView.curveSet
        pendingInteractiveCurveSet = nil

        renderCurrentImage(
            quality: .interactive,
            curveSetOverride: curveSet
        ) { [weak self] in
            guard let self else {
                return
            }
            self.interactiveRenderInFlight = false
            if self.isDraggingCurve, self.interactiveRenderPending {
                self.startInteractiveRenderIfNeeded()
            }
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
        pendingInteractiveCurveSet = editorView.curveSet
        scheduleInteractiveRender()
    }

    @objc
    func curveEditingDidBegin() {
        isDraggingCurve = true
        interactiveRenderInFlight = false
        interactiveRenderPending = false
        pendingInteractiveCurveSet = editorView.curveSet
        fullRenderTask?.cancel()
        interactiveRenderTask?.cancel()
        Task { [renderEngine, interactiveRenderEngine] in
            await renderEngine?.cancelInFlight()
            await interactiveRenderEngine?.cancelInFlight()
        }
        statusLabel.text = "Rendering preview..."
        scheduleInteractiveRender()
    }

    @objc
    func curveEditingDidEnd() {
        isDraggingCurve = false
        interactiveRenderPending = false
        pendingInteractiveCurveSet = nil
        interactiveRenderInFlight = false
        renderCurrentImage(quality: .full)
    }
}
