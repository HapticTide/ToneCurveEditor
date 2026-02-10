//
//  ToneCurveRenderingTests.swift
//  ToneCurveEditor
//
//  Created by Sun on 2026/02/10.
//

import CoreGraphics
import CoreImage
import Metal
import Testing
import ToneCurveEditor

@Test("ToneCurveLUT 输出长度符合 RGBA 布局")
func toneCurveLUTSize() throws {
    let lut = try ToneCurveLUT(curveSet: .identity, resolution: 1024)
    #expect(lut.rgba.count == 1024 * 4)
    #expect(lut.float16Data().count == 1024 * 4 * MemoryLayout<UInt16>.stride)
}

@Test("CIColorCube 回退渲染器保持 extent 并应用曲线")
func colorCubeRendererAppliesCurve() throws {
    let renderer = try ToneCurveColorCubeRenderer(cubeDimension: 32)
    let image = CIImage(color: CIColor(red: 1, green: 1, blue: 1, alpha: 1))
        .cropped(to: CGRect(x: 0, y: 0, width: 1, height: 1))

    let master = try ToneCurve(points: [
        .init(x: 0, y: 0),
        .init(x: 1, y: 0.5),
    ])
    let curveSet = ToneCurveSet(master: master, red: .linear, green: .linear, blue: .linear)

    let output = try renderer.render(image: image, curveSet: curveSet)
    #expect(output.extent.equalTo(image.extent))

    let pixel = renderSinglePixel(output)
    #expect(abs(pixel.r - 0.5) < 0.05)
    #expect(abs(pixel.g - 0.5) < 0.05)
    #expect(abs(pixel.b - 0.5) < 0.05)
}

@Test("RenderEngine 在 colorCubeOnly 模式下可渲染")
func renderEngineColorCubeMode() async throws {
    let engine = try ToneCurveRenderEngine(
        backendPreference: .colorCubeOnly,
        cubeDimension: 16
    )
    #expect(engine.usingMetal == false)

    let image = CIImage(color: CIColor(red: 0.8, green: 0.4, blue: 0.2, alpha: 1))
        .cropped(to: CGRect(x: 0, y: 0, width: 2, height: 2))
    let output = try await engine.render(image: image, curveSet: .identity)
    #expect(output.extent.equalTo(image.extent))
}

@Test("Metal 可用时能够初始化 Metal 渲染器")
func metalRendererInitWhenAvailable() throws {
    guard MTLCreateSystemDefaultDevice() != nil else {
        return
    }
    _ = try ToneCurveMetalRenderer(lutResolution: 256)
}

private struct RGBA {
    let r: Float
    let g: Float
    let b: Float
    let a: Float
}

private func renderSinglePixel(_ image: CIImage) -> RGBA {
    let context = CIContext(options: [
        .workingColorSpace: NSNull(),
        .outputColorSpace: NSNull(),
    ])

    var bitmap = [UInt8](repeating: 0, count: 4)
    context.render(
        image,
        toBitmap: &bitmap,
        rowBytes: 4,
        bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
        format: .RGBA8,
        colorSpace: CGColorSpaceCreateDeviceRGB()
    )

    return RGBA(
        r: Float(bitmap[0]) / 255,
        g: Float(bitmap[1]) / 255,
        b: Float(bitmap[2]) / 255,
        a: Float(bitmap[3]) / 255
    )
}
