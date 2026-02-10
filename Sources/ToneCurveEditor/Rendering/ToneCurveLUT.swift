//
//  ToneCurveLUT.swift
//  ToneCurveEditor
//
//  Created by Sun on 2026/02/10.
//

import Foundation

public struct ToneCurveLUT: Hashable, Sendable {
    public let resolution: Int
    public let rgba: [Float]

    public init(curveSet: ToneCurveSet, resolution: Int = 1024) throws {
        guard resolution >= 2 else {
            throw ToneCurveRenderingError.invalidLUTResolution(resolution)
        }
        self.resolution = resolution
        rgba = try ToneCurveSampler.makeRGBACompositeLUT(
            curveSet: curveSet,
            resolution: resolution
        )
    }

    public func float16Data() -> Data {
        var halfBits = [UInt16]()
        halfBits.reserveCapacity(rgba.count)

        for value in rgba {
            halfBits.append(Float16(value).bitPattern)
        }

        return halfBits.withUnsafeBufferPointer { buffer in
            Data(buffer: buffer)
        }
    }
}
