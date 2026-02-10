//
//  ToneCurveBenchmarkTests.swift
//  ToneCurveEditor
//
//  Created by Sun on 2026/02/10.
//

import CoreGraphics
import CoreImage
import Foundation
import Metal
import Testing
import ToneCurveEditor

@Test("Benchmark: CIColorCube 1024x1024 渲染耗时")
func benchmarkColorCubeRenderer1024() throws {
    let renderer = try ToneCurveColorCubeRenderer(cubeDimension: 64)
    let source = CIImage(color: CIColor(red: 0.52, green: 0.38, blue: 0.21, alpha: 1))
        .cropped(to: CGRect(x: 0, y: 0, width: 1024, height: 1024))

    let master = try ToneCurve(points: [
        .init(x: 0, y: 0),
        .init(x: 0.2, y: 0.08),
        .init(x: 0.5, y: 0.5),
        .init(x: 0.8, y: 0.93),
        .init(x: 1, y: 1),
    ])
    let red = try ToneCurve(points: [
        .init(x: 0, y: 0),
        .init(x: 1, y: 0.96),
    ])
    let green = try ToneCurve(points: [
        .init(x: 0, y: 0.02),
        .init(x: 1, y: 1),
    ])
    let blue = try ToneCurve(points: [
        .init(x: 0, y: 0),
        .init(x: 1, y: 1),
    ])
    let curveSet = ToneCurveSet(master: master, red: red, green: green, blue: blue)

    _ = try renderer.render(image: source, curveSet: curveSet)

    let warmupCount = 2
    for _ in 0..<warmupCount {
        _ = try renderer.render(image: source, curveSet: curveSet)
    }

    let iterationCount = 10
    var durationsMS: [Double] = []
    durationsMS.reserveCapacity(iterationCount)

    for _ in 0..<iterationCount {
        let start = CFAbsoluteTimeGetCurrent()
        _ = try renderer.render(image: source, curveSet: curveSet)
        let end = CFAbsoluteTimeGetCurrent()
        durationsMS.append((end - start) * 1000)
    }

    let avg = durationsMS.reduce(0, +) / Double(durationsMS.count)
    let minValue = durationsMS.min() ?? 0
    let maxValue = durationsMS.max() ?? 0

    print(
        """
        [Benchmark][CIColorCube][1024x1024] avg=\(String(format: "%.2f", avg))ms \
        min=\(String(format: "%.2f", minValue))ms max=\(String(format: "%.2f", maxValue))ms
        """
    )

    #expect(avg > 0)
    #expect(maxValue < 2000)
}

@Test("Benchmark: Metal 1024x1024 渲染耗时（可用时）")
func benchmarkMetalRenderer1024IfAvailable() throws {
    guard let device = MTLCreateSystemDefaultDevice() else {
        return
    }

    let renderer = try ToneCurveMetalRenderer(device: device, lutResolution: 1024)
    let source = CIImage(color: CIColor(red: 0.71, green: 0.44, blue: 0.2, alpha: 1))
        .cropped(to: CGRect(x: 0, y: 0, width: 1024, height: 1024))

    let curveSet = try ToneCurveSet(
        master: ToneCurve(points: [
            .init(x: 0, y: 0),
            .init(x: 0.25, y: 0.14),
            .init(x: 0.5, y: 0.52),
            .init(x: 0.75, y: 0.88),
            .init(x: 1, y: 1),
        ]),
        red: ToneCurve(points: [.init(x: 0, y: 0), .init(x: 1, y: 1)]),
        green: ToneCurve(points: [.init(x: 0, y: 0), .init(x: 1, y: 1)]),
        blue: ToneCurve(points: [.init(x: 0, y: 0), .init(x: 1, y: 1)])
    )

    _ = try renderer.render(image: source, curveSet: curveSet)

    let warmupCount = 2
    for _ in 0..<warmupCount {
        _ = try renderer.render(image: source, curveSet: curveSet)
    }

    let iterationCount = 10
    var durationsMS: [Double] = []
    durationsMS.reserveCapacity(iterationCount)

    for _ in 0..<iterationCount {
        let start = CFAbsoluteTimeGetCurrent()
        _ = try renderer.render(image: source, curveSet: curveSet)
        let end = CFAbsoluteTimeGetCurrent()
        durationsMS.append((end - start) * 1000)
    }

    let avg = durationsMS.reduce(0, +) / Double(durationsMS.count)
    let minValue = durationsMS.min() ?? 0
    let maxValue = durationsMS.max() ?? 0

    print(
        """
        [Benchmark][Metal][1024x1024] avg=\(String(format: "%.2f", avg))ms \
        min=\(String(format: "%.2f", minValue))ms max=\(String(format: "%.2f", maxValue))ms
        """
    )

    #expect(avg > 0)
    #expect(maxValue < 2000)
}
