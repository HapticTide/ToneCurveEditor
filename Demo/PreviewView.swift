//
//  PreviewView.swift
//  ToneCurveEditor
//
//  Created by Sun on 2026/02/10.
//

import CoreImage
import Metal
import MetalKit
import UIKit

final class PreviewView: UIView {
    var originalImage: UIImage? {
        didSet {
            originalImageView.image = originalImage
        }
    }

    var processedImage: UIImage? {
        didSet {
            processedFallbackImage = processedImage
            if processedCIImage == nil {
                processedRenderView.image = makeCIImage(from: processedImage)
            }
        }
    }

    var processedCIImage: CIImage? {
        didSet {
            if let processedCIImage {
                processedRenderView.image = processedCIImage
            } else {
                processedRenderView.image = makeCIImage(from: processedFallbackImage)
            }
        }
    }

    private let originalImageView = UIImageView()
    private let processedRenderView = CIImageMetalPreviewView()
    private let originalTitleLabel = UILabel()
    private let processedTitleLabel = UILabel()
    private var processedFallbackImage: UIImage?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
}

private extension PreviewView {
    func setupUI() {
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 12
        layer.masksToBounds = true

        originalTitleLabel.text = "Original"
        processedTitleLabel.text = "Processed"

        for label in [originalTitleLabel, processedTitleLabel] {
            label.font = .preferredFont(forTextStyle: .footnote)
            label.textAlignment = .center
            label.textColor = .secondaryLabel
        }

        originalImageView.contentMode = .scaleAspectFit
        originalImageView.backgroundColor = .black
        originalImageView.layer.cornerRadius = 8
        originalImageView.layer.masksToBounds = true
        originalImageView.translatesAutoresizingMaskIntoConstraints = false

        processedRenderView.backgroundColor = .black
        processedRenderView.layer.cornerRadius = 8
        processedRenderView.layer.masksToBounds = true
        processedRenderView.translatesAutoresizingMaskIntoConstraints = false

        for imageView in [originalImageView] {
            imageView.contentMode = .scaleAspectFit
            imageView.backgroundColor = .black
            imageView.layer.cornerRadius = 8
            imageView.layer.masksToBounds = true
            imageView.translatesAutoresizingMaskIntoConstraints = false
        }

        let originalStack = UIStackView(arrangedSubviews: [originalTitleLabel, originalImageView])
        originalStack.axis = .vertical
        originalStack.spacing = 8

        let processedStack = UIStackView(arrangedSubviews: [processedTitleLabel, processedRenderView])
        processedStack.axis = .vertical
        processedStack.spacing = 8

        let contentStack = UIStackView(arrangedSubviews: [originalStack, processedStack])
        contentStack.axis = .horizontal
        contentStack.spacing = 12
        contentStack.distribution = .fillEqually
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(contentStack)

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            contentStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),

            originalImageView.heightAnchor.constraint(greaterThanOrEqualToConstant: 140),
            processedRenderView.heightAnchor.constraint(greaterThanOrEqualToConstant: 140),
        ])
    }

    func makeCIImage(from image: UIImage?) -> CIImage? {
        guard let image else {
            return nil
        }
        return CIImage(image: image) ?? image.ciImage ?? image.cgImage.map { CIImage(cgImage: $0) }
    }
}

private final class CIImageMetalPreviewView: MTKView, MTKViewDelegate {
    var image: CIImage? {
        didSet {
            setNeedsDisplay()
        }
    }

    private let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
    private let queue: MTLCommandQueue?
    private let ciContext: CIContext?

    required init(coder: NSCoder) {
        let device = MTLCreateSystemDefaultDevice()
        queue = device?.makeCommandQueue()
        ciContext = device.map { CIContext(mtlDevice: $0) }
        super.init(coder: coder)
        configure(device: device)
    }

    override init(frame frameRect: CGRect, device: MTLDevice?) {
        let activeDevice = device ?? MTLCreateSystemDefaultDevice()
        queue = activeDevice?.makeCommandQueue()
        ciContext = activeDevice.map { CIContext(mtlDevice: $0) }
        super.init(frame: frameRect, device: activeDevice)
        configure(device: activeDevice)
    }

    convenience init() {
        self.init(frame: .zero, device: MTLCreateSystemDefaultDevice())
    }

    private func configure(device: MTLDevice?) {
        self.device = device
        framebufferOnly = false
        isPaused = true
        enableSetNeedsDisplay = true
        autoResizeDrawable = true
        delegate = self
        clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        contentMode = .scaleAspectFit
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        setNeedsDisplay()
    }

    func draw(in view: MTKView) {
        guard
            let queue,
            let commandBuffer = queue.makeCommandBuffer(),
            let drawable = currentDrawable,
            let renderPass = currentRenderPassDescriptor,
            let clearEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPass)
        else {
            return
        }
        clearEncoder.endEncoding()

        if let image, let ciContext {
            let drawableSize = CGSize(width: drawableSize.width, height: drawableSize.height)
            if drawableSize.width > 1, drawableSize.height > 1 {
                let rendered = fittedImage(image, in: drawableSize)
                ciContext.render(
                    rendered,
                    to: drawable.texture,
                    commandBuffer: commandBuffer,
                    bounds: CGRect(origin: .zero, size: drawableSize),
                    colorSpace: colorSpace
                )
            }
        }

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private func fittedImage(_ image: CIImage, in drawableSize: CGSize) -> CIImage {
        let extent = image.extent
        guard extent.width > 0, extent.height > 0 else {
            return image
        }

        let scale = min(drawableSize.width / extent.width, drawableSize.height / extent.height)
        let scaledWidth = extent.width * scale
        let scaledHeight = extent.height * scale
        let offsetX = (drawableSize.width - scaledWidth) * 0.5
        let offsetY = (drawableSize.height - scaledHeight) * 0.5

        return image
            .transformed(by: CGAffineTransform(translationX: -extent.minX, y: -extent.minY))
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            .transformed(by: CGAffineTransform(translationX: offsetX, y: offsetY))
    }
}
