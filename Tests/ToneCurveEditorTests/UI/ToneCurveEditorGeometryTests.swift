//
//  ToneCurveEditorGeometryTests.swift
//  ToneCurveEditor
//
//  Created by Sun on 2026/02/10.
//

import CoreGraphics
import Testing
import ToneCurveEditor

@Test("拖拽约束会限制点在邻点之间")
func constrainedPointStaysBetweenNeighbors() {
    let points: [ToneCurvePoint] = [
        .init(x: 0, y: 0),
        .init(x: 0.3, y: 0.5),
        .init(x: 0.7, y: 0.5),
        .init(x: 1, y: 1),
    ]

    let constrained = ToneCurveEditorGeometry.constrainedDragPoint(
        candidate: .init(x: 0.95, y: 1.4),
        at: 1,
        points: points,
        lockEndpoints: true,
        xEpsilon: 0.01
    )

    #expect(abs(constrained.x - 0.69) < 0.000_01)
    #expect(abs(constrained.y - 1) < 0.000_01)
}

@Test("端点锁定时仅允许拖拽 y，x 保持不变")
func endpointsKeepXButAllowYWhenLocked() {
    let points: [ToneCurvePoint] = [
        .init(x: 0, y: 0),
        .init(x: 0.5, y: 0.5),
        .init(x: 1, y: 1),
    ]

    let constrained = ToneCurveEditorGeometry.constrainedDragPoint(
        candidate: .init(x: 0.2, y: 0.8),
        at: 0,
        points: points,
        lockEndpoints: true
    )

    #expect(abs(constrained.x - 0) < 0.000_01)
    #expect(abs(constrained.y - 0.8) < 0.000_01)
}

@Test("坐标映射可双向近似还原")
func coordinateMappingRoundTrip() {
    let rect = CGRect(x: 20, y: 20, width: 200, height: 160)
    let normalized = ToneCurvePoint(x: 0.25, y: 0.75)

    let viewPoint = ToneCurveEditorGeometry.viewPoint(from: normalized, in: rect)
    let restored = ToneCurveEditorGeometry.normalizedPoint(from: viewPoint, in: rect)

    #expect(abs(restored.x - normalized.x) < 0.000_01)
    #expect(abs(restored.y - normalized.y) < 0.000_01)
}

@Test("命中测试返回最近点索引")
func nearestPointIndexHitTest() {
    let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
    let points: [ToneCurvePoint] = [
        .init(x: 0, y: 0),
        .init(x: 0.5, y: 0.5),
        .init(x: 1, y: 1),
    ]

    let hit = ToneCurveEditorGeometry.nearestPointIndex(
        to: CGPoint(x: 48, y: 52),
        points: points,
        in: rect,
        maxDistance: 12
    )
    #expect(hit == 1)

    let miss = ToneCurveEditorGeometry.nearestPointIndex(
        to: CGPoint(x: 50, y: 10),
        points: points,
        in: rect,
        maxDistance: 8
    )
    #expect(miss == nil)
}
