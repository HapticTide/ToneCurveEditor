//
//  ToneCurveRendering.swift
//  ToneCurveEditor
//
//  Created by Sun on 2026/02/10.
//

import CoreImage
import Foundation

public enum ToneCurveRenderingError: Error, Sendable {
    case invalidLUTResolution(Int)
    case invalidCubeDimension(Int)
    case filterUnavailable(String)
    case filterOutputUnavailable(String)
    case metalUnavailable
    case commandQueueUnavailable
    case pipelineUnavailable(String)
    case textureCreationFailed
    case invalidImageExtent
    case outputImageCreationFailed
}

public protocol ToneCurveRendering: Sendable {
    func render(image: CIImage, curveSet: ToneCurveSet) throws -> CIImage
}
