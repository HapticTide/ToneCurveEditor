//
//  ToneCurveColorCubeRenderer.swift
//  ToneCurveEditor
//
//  Created by Sun on 2026/02/10.
//

import CoreImage
import Foundation

public struct ToneCurveColorCubeRenderer: ToneCurveRendering {
    public let cubeDimension: Int

    public init(cubeDimension: Int = 64) throws {
        guard cubeDimension >= 2 else {
            throw ToneCurveRenderingError.invalidCubeDimension(cubeDimension)
        }
        self.cubeDimension = cubeDimension
    }

    public func render(image: CIImage, curveSet: ToneCurveSet) throws -> CIImage {
        guard let filter = CIFilter(name: "CIColorCube") else {
            throw ToneCurveRenderingError.filterUnavailable("CIColorCube")
        }

        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(cubeDimension, forKey: "inputCubeDimension")
        try filter.setValue(makeCubeData(curveSet: curveSet), forKey: "inputCubeData")

        guard let output = filter.outputImage else {
            throw ToneCurveRenderingError.filterOutputUnavailable("CIColorCube")
        }
        return output
    }

    private func makeCubeData(curveSet: ToneCurveSet) throws -> Data {
        let size = cubeDimension * cubeDimension * cubeDimension * 4
        var cubeData = [Float]()
        cubeData.reserveCapacity(size)

        let denominator = Float(cubeDimension - 1)

        for blueIndex in 0..<cubeDimension {
            let blueInput = Float(blueIndex) / denominator
            let blueMaster = ToneCurveSampler.sample(curve: curveSet.master, at: blueInput)
            let blueOutput = ToneCurveSampler.sample(curve: curveSet.blue, at: blueMaster)

            for greenIndex in 0..<cubeDimension {
                let greenInput = Float(greenIndex) / denominator
                let greenMaster = ToneCurveSampler.sample(curve: curveSet.master, at: greenInput)
                let greenOutput = ToneCurveSampler.sample(curve: curveSet.green, at: greenMaster)

                for redIndex in 0..<cubeDimension {
                    let redInput = Float(redIndex) / denominator
                    let redMaster = ToneCurveSampler.sample(curve: curveSet.master, at: redInput)
                    let redOutput = ToneCurveSampler.sample(curve: curveSet.red, at: redMaster)

                    cubeData.append(redOutput)
                    cubeData.append(greenOutput)
                    cubeData.append(blueOutput)
                    cubeData.append(1)
                }
            }
        }

        return cubeData.withUnsafeBufferPointer { buffer in
            Data(buffer: buffer)
        }
    }
}
