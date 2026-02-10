//
//  ToneCurveEditorSchemeTests.swift
//  ToneCurveEditor
//
//  Created by Sun on 2026/02/10.
//

import ToneCurveEditor
import XCTest

final class ToneCurveEditorSchemeTests: XCTestCase {
    func testCoreAPIInSchemeTestAction() throws {
        let curve = try ToneCurve(points: [
            .init(x: 0, y: 0),
            .init(x: 0.5, y: 0.6),
            .init(x: 1, y: 1),
        ])

        let sampled = ToneCurveSampler.sample(curve: curve, at: 0.5)
        XCTAssertGreaterThan(sampled, 0)
        XCTAssertLessThanOrEqual(sampled, 1)
    }
}
