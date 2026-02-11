//
//  ToneCurveRenderEngine.swift
//  ToneCurveEditor
//
//  Created by Sun on 2026/02/10.
//

import CoreImage
import Foundation
import Metal

public actor ToneCurveRenderEngine {
    public enum BackendPreference: Sendable {
        case metalPreferred
        case colorCubeOnly
    }

    public nonisolated let usingMetal: Bool

    private let renderer: any ToneCurveRendering
    private var requestSerial: UInt64 = 0
    private var inFlightTask: Task<CIImage, Error>?

    public init(
        backendPreference: BackendPreference = .metalPreferred,
        lutResolution: Int = 1024,
        cubeDimension: Int = 64,
        metalDevice: MTLDevice? = MTLCreateSystemDefaultDevice()
    ) throws {
        switch backendPreference {
        case .metalPreferred:
            if
                let metalRenderer = try? ToneCurveMetalRenderer(
                    device: metalDevice,
                    lutResolution: lutResolution
                ) {
                renderer = metalRenderer
                usingMetal = true
            } else {
                renderer = try ToneCurveColorCubeRenderer(cubeDimension: cubeDimension)
                usingMetal = false
            }
        case .colorCubeOnly:
            renderer = try ToneCurveColorCubeRenderer(cubeDimension: cubeDimension)
            usingMetal = false
        }
    }

    public func render(image: CIImage, curveSet: ToneCurveSet) async throws -> CIImage {
        requestSerial &+= 1
        let requestID = requestSerial

        inFlightTask?.cancel()

        let renderer = renderer
        let task = Task(priority: .userInitiated) {
            try Task.checkCancellation()
            let output: CIImage
            if let metalRenderer = renderer as? ToneCurveMetalRenderer {
                output = try await metalRenderer.renderAsync(image: image, curveSet: curveSet)
            } else {
                output = try renderer.render(image: image, curveSet: curveSet)
            }
            try Task.checkCancellation()
            return output
        }

        inFlightTask = task

        do {
            let output = try await task.value
            if requestID != requestSerial {
                throw CancellationError()
            }
            if requestID == requestSerial {
                inFlightTask = nil
            }
            return output
        } catch {
            if requestID == requestSerial {
                inFlightTask = nil
            }
            throw error
        }
    }

    public func cancelInFlight() {
        inFlightTask?.cancel()
        inFlightTask = nil
    }
}
