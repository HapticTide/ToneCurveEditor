//
//  ToneCurvePoint.swift
//  ToneCurveEditor
//
//  Created by Sun on 2026/02/10.
//

import Foundation

public struct ToneCurvePoint: Hashable, Sendable {
    public var x: Float
    public var y: Float

    public init(x: Float, y: Float) {
        self.x = x
        self.y = y
    }
}

extension ToneCurvePoint {
    static let minValue: Float = 0
    static let maxValue: Float = 1

    var clamped: ToneCurvePoint {
        ToneCurvePoint(
            x: x.clamped(to: Self.minValue...Self.maxValue),
            y: y.clamped(to: Self.minValue...Self.maxValue)
        )
    }
}

extension Float {
    func clamped(to range: ClosedRange<Float>) -> Float {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
