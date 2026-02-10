//
//  ToneCurveCoreModelTests.swift
//  ToneCurveEditor
//
//  Created by Sun on 2026/02/10.
//

import Testing
import ToneCurveEditor

@Test("ToneCurve.linear 使用默认 5 点并满足 x=y")
func linearCurveDefaults() throws {
    let points = ToneCurve.linear.points
    #expect(points.count == ToneCurve.defaultPointCount)
    #expect(try abs(#require(points.first?.x) - 0) < 0.000_001)
    #expect(try abs(#require(points.last?.x) - 1) < 0.000_001)

    for point in points {
        #expect(abs(point.x - point.y) < 0.000_001)
    }
}

@Test("ToneCurve.validate 对点数不足报错")
func validateInsufficientPoints() {
    do {
        try ToneCurve.validate(points: [.init(x: 0, y: 0)])
        Issue.record("expected insufficientPoints error")
    } catch let error as ToneCurveError {
        #expect(error == .insufficientPoints(minimum: 2, actual: 1))
    } catch {
        Issue.record("unexpected error: \(String(describing: error))")
    }
}

@Test("ToneCurve.validate 对 x 非严格递增报错")
func validateNonIncreasingX() {
    do {
        try ToneCurve.validate(points: [
            .init(x: 0, y: 0),
            .init(x: 0.5, y: 0.5),
            .init(x: 0.5, y: 0.6),
        ])
        Issue.record("expected nonIncreasingX error")
    } catch let error as ToneCurveError {
        #expect(error == .nonIncreasingX)
    } catch {
        Issue.record("unexpected error: \(String(describing: error))")
    }
}

@Test("ToneCurve.validate 对非有限值报错")
func validateNonFinitePoint() {
    do {
        try ToneCurve.validate(points: [
            .init(x: 0, y: 0),
            .init(x: .infinity, y: 1),
        ])
        Issue.record("expected nonFinitePoint error")
    } catch let error as ToneCurveError {
        #expect(error == .nonFinitePoint)
    } catch {
        Issue.record("unexpected error: \(String(describing: error))")
    }
}

@Test("ToneCurve.init 对非有限值报错")
func initNonFinitePoint() {
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

@Test("normalized 空输入返回空数组")
func normalizedEmptyInput() {
    let normalized = ToneCurve.normalized(points: [])
    #expect(normalized.isEmpty)
}

@Test("normalized 会排序、去重并补齐端点")
func normalizedSortDeduplicateAndPadEndpoints() {
    let normalized = ToneCurve.normalized(points: [
        .init(x: 0.9, y: 0.8),
        .init(x: 0.2, y: 1.2),
        .init(x: 0.2, y: 0.4),
        .init(x: -0.2, y: 0.3),
    ])

    #expect(normalized.count == 4)
    #expect(abs(normalized[0].x - 0) < 0.000_001)
    #expect(abs(normalized[normalized.count - 1].x - 1) < 0.000_001)

    for index in 1..<normalized.count {
        #expect(normalized[index].x > normalized[index - 1].x)
    }
}

@Test("normalized 对相同 x 仅保留最后一个点")
func normalizedDuplicateXKeepsLastPoint() {
    let normalized = ToneCurve.normalized(points: [
        .init(x: 0.3, y: 0.2),
        .init(x: 0.3, y: 0.7),
        .init(x: 0.9, y: 0.8),
    ])

    #expect(normalized.count == 3)
    #expect(abs(normalized[1].x - 0.3) < 0.000_001)
    #expect(abs(normalized[1].y - 0.7) < 0.000_001)
}

@Test("单点输入初始化时会自动补齐端点")
func initWithSinglePointPadsEndpoints() throws {
    let curve = try ToneCurve(points: [
        .init(x: 0.4, y: 0.6),
    ])

    #expect(curve.points.count == 3)
    #expect(abs(curve.points[0].x - 0) < 0.000_001)
    #expect(abs(curve.points[1].x - 0.4) < 0.000_001)
    #expect(abs(curve.points[2].x - 1) < 0.000_001)
    #expect(abs(curve.points[0].y - 0.6) < 0.000_001)
    #expect(abs(curve.points[2].y - 0.6) < 0.000_001)
}

@Test("replacePoints 会更新曲线并自动补端点")
func replacePointsUpdatesCurve() throws {
    var curve = ToneCurve.linear

    try curve.replacePoints(with: [
        .init(x: 0.2, y: 0.1),
        .init(x: 0.8, y: 0.9),
    ])

    #expect(curve.points.count == 4)
    #expect(abs(curve.points[0].x - 0) < 0.000_001)
    #expect(abs(curve.points[3].x - 1) < 0.000_001)
}

@Test("replacePoints 对非有限值报错")
func replacePointsNonFinitePoint() {
    do {
        var curve = ToneCurve.linear
        try curve.replacePoints(with: [
            .init(x: 0, y: 0),
            .init(x: 1, y: .infinity),
        ])
        Issue.record("expected nonFinitePoint error")
    } catch let error as ToneCurveError {
        #expect(error == .nonFinitePoint)
    } catch {
        Issue.record("unexpected error: \(String(describing: error))")
    }
}

@Test("ToneCurveSet 下标可读写通道曲线")
func toneCurveSetSubscriptReadWrite() throws {
    var set = ToneCurveSet.identity
    let redCurve = try ToneCurve(points: [
        .init(x: 0, y: 0),
        .init(x: 1, y: 0.8),
    ])

    set[.red] = redCurve
    #expect(set.red == redCurve)
    #expect(set[.red] == redCurve)
}

@Test("ToneCurveSet 支持所有通道下标读写")
func toneCurveSetSubscriptAllChannels() throws {
    let masterCurve = try ToneCurve(points: [.init(x: 0, y: 0.1), .init(x: 1, y: 0.9)])
    let greenCurve = try ToneCurve(points: [.init(x: 0, y: 0.2), .init(x: 1, y: 0.8)])
    let blueCurve = try ToneCurve(points: [.init(x: 0, y: 0.3), .init(x: 1, y: 0.7)])

    var set = ToneCurveSet.identity
    set[.master] = masterCurve
    set[.green] = greenCurve
    set[.blue] = blueCurve

    #expect(set.master == masterCurve)
    #expect(set.green == greenCurve)
    #expect(set.blue == blueCurve)
}
