//
//  ToneCurveSamplerCoreTests.swift
//  ToneCurveEditor
//
//  Created by Sun on 2026/02/10.
//

import Testing
import ToneCurveEditor

@Test("采样点在曲线定义域外时夹到端点")
func sampleOutsideRangeClampsToEndpoints() throws {
    let curve = try ToneCurve(points: [
        .init(x: 0, y: 0.1),
        .init(x: 1, y: 0.9),
    ])

    #expect(abs(ToneCurveSampler.sample(curve: curve, at: -1) - 0.1) < 0.000_001)
    #expect(abs(ToneCurveSampler.sample(curve: curve, at: 2) - 0.9) < 0.000_001)
}

@Test("两点曲线采样走线性插值")
func twoPointCurveLinearInterpolation() throws {
    let curve = try ToneCurve(points: [
        .init(x: 0, y: 0),
        .init(x: 1, y: 1),
    ])

    let mid = ToneCurveSampler.sample(curve: curve, at: 0.5)
    #expect(abs(mid - 0.5) < 0.000_01)
}

@Test("两点极近 x 距离时采样回退到终点值")
func twoPointCurveWithTinyDeltaXFallsBackToEndpoint() throws {
    let curve = try ToneCurve(points: [
        .init(x: 0, y: 0.2),
        .init(x: 0.000_000_1, y: 0.9),
    ])

    let sampled = ToneCurveSampler.sample(curve: curve, at: 0.000_000_05)
    #expect(abs(sampled - 0.9) < 0.000_001)
}

@Test("多点曲线在控制点处采样返回控制点 y")
func sampleOnControlPointsReturnsExactY() throws {
    let curve = try ToneCurve(points: [
        .init(x: 0, y: 0),
        .init(x: 0.25, y: 0.3),
        .init(x: 0.6, y: 0.5),
        .init(x: 1, y: 1),
    ])

    for point in curve.points {
        let sampled = ToneCurveSampler.sample(curve: curve, at: point.x)
        #expect(abs(sampled - point.y) < 0.000_01)
    }
}

@Test("单调输入点采样结果保持非递减")
func monotoneCurveSamplingRemainsNonDecreasing() throws {
    let curve = try ToneCurve(points: [
        .init(x: 0, y: 0),
        .init(x: 0.2, y: 0.1),
        .init(x: 0.4, y: 0.6),
        .init(x: 0.7, y: 0.8),
        .init(x: 1, y: 1),
    ])

    var previous = Float.zero
    for index in 0...512 {
        let x = Float(index) / 512
        let current = ToneCurveSampler.sample(curve: curve, at: x)
        #expect(current + 0.000_01 >= previous)
        previous = current
    }
}

@Test("平台段采样不会出现过冲")
func flatSegmentSamplingNoOvershoot() throws {
    let curve = try ToneCurve(points: [
        .init(x: 0, y: 0.2),
        .init(x: 0.3, y: 0.2),
        .init(x: 0.6, y: 0.2),
        .init(x: 1, y: 0.9),
    ])

    for index in 0...120 {
        let x = Float(index) / 200
        let sampled = ToneCurveSampler.sample(curve: curve, at: x)
        #expect(sampled >= 0.2 - 0.000_01)
        #expect(sampled <= 0.9 + 0.000_01)
    }
}

@Test("LUT 输出长度与值域正确")
func lutLengthAndRange() throws {
    let curve = try ToneCurve(points: [
        .init(x: 0, y: 0.2),
        .init(x: 1, y: 0.8),
    ])
    let lut = try ToneCurveSampler.makeLUT(curve: curve, resolution: 33)

    #expect(lut.count == 33)
    for value in lut {
        #expect(value >= 0)
        #expect(value <= 1)
    }
}

@Test("LUT 最小合法分辨率为 2")
func lutMinimumValidResolution() throws {
    let lut = try ToneCurveSampler.makeLUT(curve: .linear, resolution: 2)
    #expect(lut.count == 2)
    #expect(abs(lut[0] - 0) < 0.000_001)
    #expect(abs(lut[1] - 1) < 0.000_001)
}

@Test("LUT 对非法分辨率报错")
func lutInvalidResolutionThrows() {
    do {
        _ = try ToneCurveSampler.makeLUT(curve: .linear, resolution: 1)
        Issue.record("expected invalidResolution error")
    } catch let error as ToneCurveSamplerError {
        #expect(error == .invalidResolution(1))
    } catch {
        Issue.record("unexpected error: \(String(describing: error))")
    }
}

@Test("LUT 对 0 分辨率报错")
func lutZeroResolutionThrows() {
    do {
        _ = try ToneCurveSampler.makeLUT(curve: .linear, resolution: 0)
        Issue.record("expected invalidResolution error")
    } catch let error as ToneCurveSamplerError {
        #expect(error == .invalidResolution(0))
    } catch {
        Issue.record("unexpected error: \(String(describing: error))")
    }
}

@Test("RGBA 组合 LUT 的 alpha 恒为 1")
func rgbaCompositeAlphaChannel() throws {
    let set = ToneCurveSet.identity
    let lut = try ToneCurveSampler.makeRGBACompositeLUT(curveSet: set, resolution: 16)

    #expect(lut.count == 16 * 4)
    for index in stride(from: 3, to: lut.count, by: 4) {
        #expect(abs(lut[index] - 1) < 0.000_001)
    }
}

@Test("RGBA 组合 LUT 先应用 master 再应用分通道")
func rgbaCompositeAppliesMasterThenChannels() throws {
    let master = try ToneCurve(points: [
        .init(x: 0, y: 0.5),
        .init(x: 1, y: 0.5),
    ])
    let red = try ToneCurve(points: [
        .init(x: 0, y: 0.1),
        .init(x: 1, y: 0.9),
    ])
    let green = ToneCurve.linear
    let blue = try ToneCurve(points: [
        .init(x: 0, y: 1),
        .init(x: 1, y: 0),
    ])
    let set = ToneCurveSet(master: master, red: red, green: green, blue: blue)

    let lut = try ToneCurveSampler.makeRGBACompositeLUT(curveSet: set, resolution: 4)

    for offset in stride(from: 0, to: lut.count, by: 4) {
        #expect(abs(lut[offset] - 0.5) < 0.000_1)
        #expect(abs(lut[offset + 1] - 0.5) < 0.000_1)
        #expect(abs(lut[offset + 2] - 0.5) < 0.000_1)
        #expect(abs(lut[offset + 3] - 1) < 0.000_001)
    }
}

@Test("RGBA 组合 LUT 对非法分辨率报错")
func rgbaCompositeInvalidResolutionThrows() {
    do {
        _ = try ToneCurveSampler.makeRGBACompositeLUT(curveSet: .identity, resolution: 1)
        Issue.record("expected invalidResolution error")
    } catch let error as ToneCurveSamplerError {
        #expect(error == .invalidResolution(1))
    } catch {
        Issue.record("unexpected error: \(String(describing: error))")
    }
}
