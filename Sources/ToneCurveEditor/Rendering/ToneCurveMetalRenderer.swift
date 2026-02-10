//
//  ToneCurveMetalRenderer.swift
//  ToneCurveEditor
//
//  Created by Sun on 2026/02/10.
//

import CoreGraphics
import CoreImage
import Foundation
import Metal

public final class ToneCurveMetalRenderer: @unchecked Sendable, ToneCurveRendering {
    private static let kernelFunctionName = "toneCurveKernel"
    private static let shaderSource = """
    #include <metal_stdlib>
    using namespace metal;

    kernel void toneCurveKernel(
        texture2d<half, access::read> inputTexture [[texture(0)]],
        texture2d<half, access::write> outputTexture [[texture(1)]],
        texture2d<half, access::sample> lutTexture [[texture(2)]],
        uint2 gid [[thread_position_in_grid]]
    ) {
        if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
            return;
        }

        constexpr sampler lutSampler(address::clamp_to_edge, filter::linear);
        half4 source = inputTexture.read(gid);

        float r = clamp(float(source.r), 0.0, 1.0);
        float g = clamp(float(source.g), 0.0, 1.0);
        float b = clamp(float(source.b), 0.0, 1.0);

        half mappedR = lutTexture.sample(lutSampler, float2(r, 0.5)).r;
        half mappedG = lutTexture.sample(lutSampler, float2(g, 0.5)).g;
        half mappedB = lutTexture.sample(lutSampler, float2(b, 0.5)).b;

        outputTexture.write(half4(mappedR, mappedG, mappedB, source.a), gid);
    }
    """

    public let lutResolution: Int
    public let device: MTLDevice
    public let ciContext: CIContext

    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLComputePipelineState
    private let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()

    public init(
        device: MTLDevice? = MTLCreateSystemDefaultDevice(),
        lutResolution: Int = 1024,
        ciContext: CIContext? = nil
    ) throws {
        guard lutResolution >= 2 else {
            throw ToneCurveRenderingError.invalidLUTResolution(lutResolution)
        }
        guard let device else {
            throw ToneCurveRenderingError.metalUnavailable
        }
        guard let commandQueue = device.makeCommandQueue() else {
            throw ToneCurveRenderingError.commandQueueUnavailable
        }

        let library = try device.makeLibrary(source: Self.shaderSource, options: nil)
        guard let function = library.makeFunction(name: Self.kernelFunctionName) else {
            throw ToneCurveRenderingError.pipelineUnavailable(Self.kernelFunctionName)
        }

        pipelineState = try device.makeComputePipelineState(function: function)
        self.device = device
        self.commandQueue = commandQueue
        self.lutResolution = lutResolution
        self.ciContext = ciContext ?? CIContext(mtlDevice: device)
    }

    public func render(image: CIImage, curveSet: ToneCurveSet) throws -> CIImage {
        let extent = image.extent.integral
        guard extent.width > 0, extent.height > 0 else {
            throw ToneCurveRenderingError.invalidImageExtent
        }

        let width = Int(extent.width)
        let height = Int(extent.height)

        guard
            let inputTexture = makeImageTexture(width: width, height: height),
            let outputTexture = makeImageTexture(width: width, height: height),
            let lutTexture = try makeLUTTexture(curveSet: curveSet)
        else {
            throw ToneCurveRenderingError.textureCreationFailed
        }

        ciContext.render(
            image,
            to: inputTexture,
            commandBuffer: nil,
            bounds: extent,
            colorSpace: colorSpace
        )

        guard
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let encoder = commandBuffer.makeComputeCommandEncoder()
        else {
            throw ToneCurveRenderingError.commandQueueUnavailable
        }

        encoder.setComputePipelineState(pipelineState)
        encoder.setTexture(inputTexture, index: 0)
        encoder.setTexture(outputTexture, index: 1)
        encoder.setTexture(lutTexture, index: 2)

        let threadWidth = max(1, pipelineState.threadExecutionWidth)
        let threadHeight = max(1, pipelineState.maxTotalThreadsPerThreadgroup / threadWidth)
        let threadsPerGroup = MTLSize(width: threadWidth, height: threadHeight, depth: 1)
        let threadgroupsPerGrid = MTLSize(
            width: (width + threadWidth - 1) / threadWidth,
            height: (height + threadHeight - 1) / threadHeight,
            depth: 1
        )

        // Use dispatchThreadgroups for broad device/simulator compatibility.
        // The kernel already guards out-of-bounds gid, so over-dispatch is safe.
        encoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerGroup)
        encoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        if commandBuffer.status == .error {
            throw commandBuffer.error ?? ToneCurveRenderingError.pipelineUnavailable("CommandBuffer failed")
        }

        guard var outputImage = CIImage(mtlTexture: outputTexture, options: [.colorSpace: colorSpace]) else {
            throw ToneCurveRenderingError.outputImageCreationFailed
        }

        outputImage = outputImage
            .transformed(
                by: CGAffineTransform(
                    translationX: extent.origin.x,
                    y: extent.origin.y
                )
            )
            .cropped(to: extent)

        return outputImage
    }

    private func makeImageTexture(width: Int, height: Int) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba16Float,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        descriptor.storageMode = .private
        return device.makeTexture(descriptor: descriptor)
    }

    private func makeLUTTexture(curveSet: ToneCurveSet) throws -> MTLTexture? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba16Float,
            width: lutResolution,
            height: 1,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead]
        descriptor.storageMode = .shared

        guard let texture = device.makeTexture(descriptor: descriptor) else {
            return nil
        }

        let lut = try ToneCurveLUT(curveSet: curveSet, resolution: lutResolution)
        let bytes = lut.float16Data()
        let bytesPerPixel = MemoryLayout<UInt16>.stride * 4
        let bytesPerRow = lutResolution * bytesPerPixel

        bytes.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else {
                return
            }
            texture.replace(
                region: MTLRegionMake2D(0, 0, lutResolution, 1),
                mipmapLevel: 0,
                withBytes: baseAddress,
                bytesPerRow: bytesPerRow
            )
        }

        return texture
    }
}
