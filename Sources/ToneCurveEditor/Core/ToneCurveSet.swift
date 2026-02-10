//
//  ToneCurveSet.swift
//  ToneCurveEditor
//
//  Created by Sun on 2026/02/10.
//

import Foundation

public enum ToneCurveChannel: CaseIterable, Sendable {
    case master
    case red
    case green
    case blue
}

public struct ToneCurveSet: Hashable, Sendable {
    public var master: ToneCurve
    public var red: ToneCurve
    public var green: ToneCurve
    public var blue: ToneCurve

    public init(
        master: ToneCurve = .linear,
        red: ToneCurve = .linear,
        green: ToneCurve = .linear,
        blue: ToneCurve = .linear
    ) {
        self.master = master
        self.red = red
        self.green = green
        self.blue = blue
    }

    public static let identity = ToneCurveSet()

    public subscript(channel: ToneCurveChannel) -> ToneCurve {
        get {
            switch channel {
            case .master:
                master
            case .red:
                red
            case .green:
                green
            case .blue:
                blue
            }
        }
        set {
            switch channel {
            case .master:
                master = newValue
            case .red:
                red = newValue
            case .green:
                green = newValue
            case .blue:
                blue = newValue
            }
        }
    }
}
