//
//  ToneCurveEditorTests.swift
//  ToneCurveEditor
//
//  Created by Sun on 2026/02/10.
//

import Testing
import ToneCurveEditor

@Test("ToneCurve 规范化会执行排序、去重、clamp，并补齐端点")
func toneCurveNormalization() throws {
    let curve = try ToneCurve(points: [
        .init(x: 0.8, y: 1.2),
        .init(x: 0.2, y: -0.3),
        .init(x: 0.2, y: 0.4),
    ])

    #expect(curve.points.count == 4)
    assertApproximately(curve.points[0], .init(x: 0, y: 0.4))
    assertApproximately(curve.points[1], .init(x: 0.2, y: 0.4))
    assertApproximately(curve.points[2], .init(x: 0.8, y: 1))
    assertApproximately(curve.points[3], .init(x: 1, y: 1))
}

@Test("ToneCurve 对 non-finite 输入报错")
func nonFinitePointThrows() {
    do {
        _ = try ToneCurve(points: [
            .init(x: 0, y: 0),
            .init(x: 1, y: .nan),
        ])
        Issue.record("expected nonFinitePoint error")
    } catch let error as ToneCurveError {
        #expect(error == .nonFinitePoint)
    } catch {
        Issue.record("unexpected error: \(String(describing: error))")
    }
}

@Test("线性曲线边界采样正确")
func linearCurveBoundarySampling() throws {
    let curve = ToneCurve.linear
    #expect(abs(ToneCurveSampler.sample(curve: curve, at: 0) - 0) < 0.000_001)
    #expect(abs(ToneCurveSampler.sample(curve: curve, at: 1) - 1) < 0.000_001)

    let lut = try ToneCurveSampler.makeLUT(curve: curve, resolution: 17)
    #expect(try abs(#require(lut.first) - 0) < 0.000_001)
    #expect(try abs(#require(lut.last) - 1) < 0.000_001)
}

@Test("单调输入点生成的 LUT 保持非递减")
func monotoneCurveProducesMonotoneLUT() throws {
    let curve = try ToneCurve(points: [
        .init(x: 0, y: 0),
        .init(x: 0.2, y: 0.1),
        .init(x: 0.5, y: 0.7),
        .init(x: 1, y: 1),
    ])

    let lut = try ToneCurveSampler.makeLUT(curve: curve, resolution: 256)
    for index in 1..<lut.count {
        #expect(lut[index] + 0.000_01 >= lut[index - 1])
    }
}

@Test("Master -> RGB 叠加顺序正确")
func compositeLUTOrder() throws {
    let master = try ToneCurve(points: [
        .init(x: 0, y: 0),
        .init(x: 1, y: 0.5),
    ])
    let red = try ToneCurve(points: [
        .init(x: 0, y: 0),
        .init(x: 1, y: 1),
    ])
    let green = try ToneCurve(points: [
        .init(x: 0, y: 0),
        .init(x: 1, y: 0),
    ])
    let blue = try ToneCurve(points: [
        .init(x: 0, y: 1),
        .init(x: 1, y: 1),
    ])
    let set = ToneCurveSet(master: master, red: red, green: green, blue: blue)

    let lut = try ToneCurveSampler.makeRGBACompositeLUT(curveSet: set, resolution: 3)
    let offset = 2 * 4

    #expect(abs(lut[offset] - 0.5) < 0.000_01)
    #expect(abs(lut[offset + 1] - 0) < 0.000_01)
    #expect(abs(lut[offset + 2] - 1) < 0.000_01)
    #expect(abs(lut[offset + 3] - 1) < 0.000_01)
}

@Test("LUT 分辨率小于 2 时报错")
func invalidResolutionThrows() {
    do {
        _ = try ToneCurveSampler.makeLUT(curve: .linear, resolution: 1)
        Issue.record("expected invalidResolution error")
    } catch let error as ToneCurveSamplerError {
        #expect(error == .invalidResolution(1))
    } catch {
        Issue.record("unexpected error: \(String(describing: error))")
    }
}

private func assertApproximately(
    _ lhs: ToneCurvePoint,
    _ rhs: ToneCurvePoint,
    tolerance: Float = 0.000_01
) {
    #expect(abs(lhs.x - rhs.x) <= tolerance)
    #expect(abs(lhs.y - rhs.y) <= tolerance)
}
