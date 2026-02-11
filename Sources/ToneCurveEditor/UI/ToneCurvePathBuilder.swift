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
        samplesPerSegment: Int = 64
    ) -> CGPath {
        let points = curve.points
        guard points.count >= 2 else {
            return CGMutablePath()
        }

        let segmentSampleCount = max(2, samplesPerSegment)
        let path = CGMutablePath()
        var didMove = false

        for segmentIndex in 0..<(points.count - 1) {
            let start = points[segmentIndex]
            let end = points[segmentIndex + 1]

            for sampleIndex in 0...segmentSampleCount {
                if segmentIndex > 0, sampleIndex == 0 {
                    continue
                }

                let t = Float(sampleIndex) / Float(segmentSampleCount)
                let x = start.x + ((end.x - start.x) * t)
                let y = ToneCurveSampler.sample(curve: curve, at: x)
                let point = ToneCurveEditorGeometry.viewPoint(
                    from: ToneCurvePoint(x: x, y: y),
                    in: plotRect
                )

                if !didMove {
                    path.move(to: point)
                    didMove = true
                } else {
                    path.addLine(to: point)
                }
            }
        }

        return path
    }
}
