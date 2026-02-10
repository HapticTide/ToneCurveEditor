//
//  ToneCurve.swift
//  ToneCurveEditor
//
//  Created by Sun on 2026/02/10.
//

import Foundation

public enum ToneCurveError: Error, Equatable, Sendable {
    case insufficientPoints(minimum: Int, actual: Int)
    case nonFinitePoint
    case nonIncreasingX
}

public struct ToneCurve: Hashable, Sendable {
    public static let defaultPointCount = 5
    static let epsilon: Float = 0.000_001

    public private(set) var points: [ToneCurvePoint]

    public init(points: [ToneCurvePoint]) throws {
        try Self.validateFinite(points: points)
        let normalized = Self.normalized(points: points)
        try Self.validate(points: normalized)
        self.points = normalized
    }

    public static let linear: ToneCurve = {
        let step = 1.0 / Float(defaultPointCount - 1)
        let points = (0..<defaultPointCount).map { index in
            let value = Float(index) * step
            return ToneCurvePoint(x: value, y: value)
        }
        return try! ToneCurve(points: points)
    }()

    public mutating func replacePoints(with points: [ToneCurvePoint]) throws {
        try Self.validateFinite(points: points)
        let normalized = Self.normalized(points: points)
        try Self.validate(points: normalized)
        self.points = normalized
    }

    public static func normalized(points: [ToneCurvePoint]) -> [ToneCurvePoint] {
        guard !points.isEmpty else {
            return []
        }

        let sorted = points
            .map(\.clamped)
            .sorted { lhs, rhs in
                if lhs.x == rhs.x {
                    return lhs.y < rhs.y
                }
                return lhs.x < rhs.x
            }

        var deduped: [ToneCurvePoint] = []
        deduped.reserveCapacity(sorted.count)

        for point in sorted {
            if let last = deduped.last, abs(last.x - point.x) <= epsilon {
                deduped[deduped.count - 1] = point
            } else {
                deduped.append(point)
            }
        }

        guard !deduped.isEmpty else {
            return []
        }

        if let first = deduped.first, first.x > ToneCurvePoint.minValue {
            deduped.insert(
                ToneCurvePoint(x: ToneCurvePoint.minValue, y: first.y),
                at: 0
            )
        }

        if let last = deduped.last, last.x < ToneCurvePoint.maxValue {
            deduped.append(
                ToneCurvePoint(x: ToneCurvePoint.maxValue, y: last.y)
            )
        }

        deduped[0].x = ToneCurvePoint.minValue
        deduped[deduped.count - 1].x = ToneCurvePoint.maxValue

        return deduped
    }

    public static func validate(points: [ToneCurvePoint]) throws {
        guard points.count >= 2 else {
            throw ToneCurveError.insufficientPoints(minimum: 2, actual: points.count)
        }

        for point in points where !point.x.isFinite || !point.y.isFinite {
            throw ToneCurveError.nonFinitePoint
        }

        for index in 1..<points.count {
            if points[index].x <= points[index - 1].x {
                throw ToneCurveError.nonIncreasingX
            }
        }
    }

    private static func validateFinite(points: [ToneCurvePoint]) throws {
        for point in points where !point.x.isFinite || !point.y.isFinite {
            throw ToneCurveError.nonFinitePoint
        }
    }
}
