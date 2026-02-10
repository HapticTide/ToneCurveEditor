//
//  ToneCurveEditorGeometry.swift
//  ToneCurveEditor
//
//  Created by Sun on 2026/02/10.
//

import CoreGraphics
import Foundation

public enum ToneCurveEditorGeometry {
    public static func viewPoint(from normalizedPoint: ToneCurvePoint, in plotRect: CGRect) -> CGPoint {
        let x = plotRect.minX + CGFloat(normalizedPoint.x) * plotRect.width
        let y = plotRect.maxY - CGFloat(normalizedPoint.y) * plotRect.height
        return CGPoint(x: x, y: y)
    }

    public static func normalizedPoint(from viewPoint: CGPoint, in plotRect: CGRect) -> ToneCurvePoint {
        if plotRect.width <= 0 || plotRect.height <= 0 {
            return ToneCurvePoint(x: 0, y: 0)
        }

        let normalizedX = Float((viewPoint.x - plotRect.minX) / plotRect.width).clamped(to: 0...1)
        let normalizedY = Float((plotRect.maxY - viewPoint.y) / plotRect.height).clamped(to: 0...1)
        return ToneCurvePoint(x: normalizedX, y: normalizedY)
    }

    public static func nearestPointIndex(
        to targetPoint: CGPoint,
        points: [ToneCurvePoint],
        in plotRect: CGRect,
        maxDistance: CGFloat
    ) -> Int? {
        guard !points.isEmpty else {
            return nil
        }

        var bestIndex: Int?
        var bestDistance = maxDistance

        for (index, point) in points.enumerated() {
            let pointInView = viewPoint(from: point, in: plotRect)
            let distance = hypot(pointInView.x - targetPoint.x, pointInView.y - targetPoint.y)

            if distance <= bestDistance {
                bestDistance = distance
                bestIndex = index
            }
        }

        return bestIndex
    }

    public static func constrainedDragPoint(
        candidate: ToneCurvePoint,
        at index: Int,
        points: [ToneCurvePoint],
        lockEndpoints: Bool = true,
        xEpsilon: Float = 0.001
    ) -> ToneCurvePoint {
        guard points.indices.contains(index) else {
            return candidate.clamped
        }

        if lockEndpoints, index == 0 || index == points.count - 1 {
            var endpointConstrained = candidate.clamped
            endpointConstrained.x = points[index].x
            return endpointConstrained
        }

        var constrained = candidate.clamped

        if index > 0 {
            let leftLimit = points[index - 1].x + xEpsilon
            constrained.x = max(constrained.x, leftLimit)
        }

        if index < points.count - 1 {
            let rightLimit = points[index + 1].x - xEpsilon
            constrained.x = min(constrained.x, rightLimit)
        }

        constrained.x = constrained.x.clamped(to: 0...1)
        constrained.y = constrained.y.clamped(to: 0...1)
        return constrained
    }
}
