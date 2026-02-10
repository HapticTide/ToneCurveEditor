//
//  ToneCurveSampler.swift
//  ToneCurveEditor
//
//  Created by Sun on 2026/02/10.
//

import Foundation

public enum ToneCurveSamplerError: Error, Equatable, Sendable {
    case invalidResolution(Int)
}

public enum ToneCurveSampler {
    public static func sample(curve: ToneCurve, at x: Float) -> Float {
        let points = curve.points
        if x <= points[0].x {
            return points[0].y
        }
        if x >= points[points.count - 1].x {
            return points[points.count - 1].y
        }

        if points.count == 2 {
            return linearSample(start: points[0], end: points[1], x: x)
        }

        let slopes = monotoneTangents(points: points)
        let segmentIndex = segmentIndex(points: points, x: x)
        return cubicHermiteSample(
            start: points[segmentIndex],
            end: points[segmentIndex + 1],
            startSlope: slopes[segmentIndex],
            endSlope: slopes[segmentIndex + 1],
            x: x
        )
    }

    public static func makeLUT(curve: ToneCurve, resolution: Int = 1024) throws -> [Float] {
        guard resolution >= 2 else {
            throw ToneCurveSamplerError.invalidResolution(resolution)
        }

        var lut: [Float] = []
        lut.reserveCapacity(resolution)
        let denominator = Float(resolution - 1)

        for index in 0..<resolution {
            let x = Float(index) / denominator
            lut.append(sample(curve: curve, at: x))
        }
        return lut
    }

    // RGBA layout: [r0, g0, b0, a0, r1, g1, b1, a1, ...]
    public static func makeRGBACompositeLUT(
        curveSet: ToneCurveSet,
        resolution: Int = 1024
    ) throws -> [Float] {
        guard resolution >= 2 else {
            throw ToneCurveSamplerError.invalidResolution(resolution)
        }

        var lut: [Float] = []
        lut.reserveCapacity(resolution * 4)
        let denominator = Float(resolution - 1)

        for index in 0..<resolution {
            let x = Float(index) / denominator
            let master = sample(curve: curveSet.master, at: x)

            lut.append(sample(curve: curveSet.red, at: master))
            lut.append(sample(curve: curveSet.green, at: master))
            lut.append(sample(curve: curveSet.blue, at: master))
            lut.append(1)
        }

        return lut
    }
}

private extension ToneCurveSampler {
    static func linearSample(start: ToneCurvePoint, end: ToneCurvePoint, x: Float) -> Float {
        let deltaX = end.x - start.x
        if deltaX <= ToneCurve.epsilon {
            return end.y.clamped(to: 0...1)
        }
        let t = (x - start.x) / deltaX
        return (start.y + t * (end.y - start.y)).clamped(to: 0...1)
    }

    static func segmentIndex(points: [ToneCurvePoint], x: Float) -> Int {
        var low = 0
        var high = points.count - 2

        while low <= high {
            let mid = (low + high) / 2
            if x < points[mid].x {
                high = mid - 1
            } else if x > points[mid + 1].x {
                low = mid + 1
            } else {
                return mid
            }
        }

        return max(0, min(points.count - 2, low))
    }

    static func cubicHermiteSample(
        start: ToneCurvePoint,
        end: ToneCurvePoint,
        startSlope: Float,
        endSlope: Float,
        x: Float
    ) -> Float {
        let h = end.x - start.x
        if h <= ToneCurve.epsilon {
            return end.y.clamped(to: 0...1)
        }

        let t = (x - start.x) / h
        let t2 = t * t
        let t3 = t2 * t

        let h00 = (2 * t3) - (3 * t2) + 1
        let h10 = t3 - (2 * t2) + t
        let h01 = (-2 * t3) + (3 * t2)
        let h11 = t3 - t2

        let y = (h00 * start.y)
            + (h10 * h * startSlope)
            + (h01 * end.y)
            + (h11 * h * endSlope)

        return y.clamped(to: 0...1)
    }

    static func monotoneTangents(points: [ToneCurvePoint]) -> [Float] {
        let n = points.count
        if n == 2 {
            let slope = (points[1].y - points[0].y) / (points[1].x - points[0].x)
            return [slope, slope]
        }

        var h = Array(repeating: Float.zero, count: n - 1)
        var delta = Array(repeating: Float.zero, count: n - 1)

        for i in 0..<(n - 1) {
            h[i] = points[i + 1].x - points[i].x
            delta[i] = h[i] <= ToneCurve.epsilon
                ? 0
                : (points[i + 1].y - points[i].y) / h[i]
        }

        var m = Array(repeating: Float.zero, count: n)
        m[0] = delta[0]
        m[n - 1] = delta[n - 2]

        if n > 2 {
            for i in 1..<(n - 1) {
                if delta[i - 1] == 0 || delta[i] == 0 || (delta[i - 1].sign != delta[i].sign) {
                    m[i] = 0
                } else {
                    let w1 = (2 * h[i]) + h[i - 1]
                    let w2 = h[i] + (2 * h[i - 1])
                    m[i] = (w1 + w2) / ((w1 / delta[i - 1]) + (w2 / delta[i]))
                }
            }
        }

        for i in 0..<(n - 1) {
            if abs(delta[i]) <= ToneCurve.epsilon {
                m[i] = 0
                m[i + 1] = 0
                continue
            }

            let a = m[i] / delta[i]
            let b = m[i + 1] / delta[i]
            let magnitude = (a * a) + (b * b)

            if magnitude > 9 {
                let tau = 3 / sqrt(magnitude)
                m[i] = tau * a * delta[i]
                m[i + 1] = tau * b * delta[i]
            }
        }

        return m
    }
}
