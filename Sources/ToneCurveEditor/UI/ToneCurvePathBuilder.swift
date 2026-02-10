//
//  ToneCurvePathBuilder.swift
//  ToneCurveEditor
//
//  Created by Sun on 2026/02/10.
//

import CoreGraphics
import Foundation

public enum ToneCurvePathBuilder {
    public static func makePath(
        for curve: ToneCurve,
        in plotRect: CGRect,
        samplesPerSegment: Int = 48
    ) -> CGPath {
        let segmentCount = max(1, curve.points.count - 1)
        let sampleCount = max(2, segmentCount * max(2, samplesPerSegment) + 1)

        let path = CGMutablePath()
        for index in 0..<sampleCount {
            let x = Float(index) / Float(sampleCount - 1)
            let y = ToneCurveSampler.sample(curve: curve, at: x)
            let point = ToneCurveEditorGeometry.viewPoint(
                from: ToneCurvePoint(x: x, y: y),
                in: plotRect
            )

            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        return path
    }
}
