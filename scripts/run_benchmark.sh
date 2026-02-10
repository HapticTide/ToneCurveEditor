#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

cat > /tmp/tonecurve_benchmark.swift <<'SWIFT'
import CoreGraphics
import CoreImage
import Foundation
import Metal

func format(_ value: Double) -> String {
    String(format: "%.2f", value)
}

@main
struct Runner {
    static func main() throws {
        let source = CIImage(color: CIColor(red: 0.62, green: 0.41, blue: 0.26, alpha: 1))
            .cropped(to: CGRect(x: 0, y: 0, width: 1024, height: 1024))

        let master = try ToneCurve(points: [
            .init(x: 0, y: 0),
            .init(x: 0.2, y: 0.08),
            .init(x: 0.5, y: 0.5),
            .init(x: 0.8, y: 0.92),
            .init(x: 1, y: 1),
        ])

        let curveSet = ToneCurveSet(
            master: master,
            red: try ToneCurve(points: [.init(x: 0, y: 0), .init(x: 1, y: 0.96)]),
            green: try ToneCurve(points: [.init(x: 0, y: 0.02), .init(x: 1, y: 1)]),
            blue: try ToneCurve(points: [.init(x: 0, y: 0), .init(x: 1, y: 1)])
        )

        let colorCubeRenderer = try ToneCurveColorCubeRenderer(cubeDimension: 64)
        _ = try colorCubeRenderer.render(image: source, curveSet: curveSet)
        for _ in 0..<2 { _ = try colorCubeRenderer.render(image: source, curveSet: curveSet) }

        var colorCubeDurations: [Double] = []
        for _ in 0..<10 {
            let start = CFAbsoluteTimeGetCurrent()
            _ = try colorCubeRenderer.render(image: source, curveSet: curveSet)
            colorCubeDurations.append((CFAbsoluteTimeGetCurrent() - start) * 1000)
        }

        let colorCubeAvg = colorCubeDurations.reduce(0,+) / Double(colorCubeDurations.count)
        print("[Benchmark][CIColorCube][1024x1024] avg=\(format(colorCubeAvg))ms min=\(format(colorCubeDurations.min() ?? 0))ms max=\(format(colorCubeDurations.max() ?? 0))ms")

        if let device = MTLCreateSystemDefaultDevice() {
            let metalRenderer = try ToneCurveMetalRenderer(device: device, lutResolution: 1024)
            _ = try metalRenderer.render(image: source, curveSet: curveSet)
            for _ in 0..<2 { _ = try metalRenderer.render(image: source, curveSet: curveSet) }

            var metalDurations: [Double] = []
            for _ in 0..<10 {
                let start = CFAbsoluteTimeGetCurrent()
                _ = try metalRenderer.render(image: source, curveSet: curveSet)
                metalDurations.append((CFAbsoluteTimeGetCurrent() - start) * 1000)
            }

            let metalAvg = metalDurations.reduce(0,+) / Double(metalDurations.count)
            print("[Benchmark][Metal][1024x1024] avg=\(format(metalAvg))ms min=\(format(metalDurations.min() ?? 0))ms max=\(format(metalDurations.max() ?? 0))ms")
        } else {
            print("[Benchmark][Metal][1024x1024] unavailable")
        }
    }
}
SWIFT

cd "$ROOT_DIR"
HOME=/tmp swiftc -O -o /tmp/tonecurve_benchmark \
  /tmp/tonecurve_benchmark.swift \
  Sources/ToneCurveEditor/Core/ToneCurvePoint.swift \
  Sources/ToneCurveEditor/Core/ToneCurve.swift \
  Sources/ToneCurveEditor/Core/ToneCurveSet.swift \
  Sources/ToneCurveEditor/Core/ToneCurveSampler.swift \
  Sources/ToneCurveEditor/Rendering/ToneCurveRendering.swift \
  Sources/ToneCurveEditor/Rendering/ToneCurveLUT.swift \
  Sources/ToneCurveEditor/Rendering/ToneCurveColorCubeRenderer.swift \
  Sources/ToneCurveEditor/Rendering/ToneCurveMetalRenderer.swift \
  Sources/ToneCurveEditor/Rendering/ToneCurveRenderEngine.swift

/tmp/tonecurve_benchmark
