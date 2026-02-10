//
//  ToneCurveEditorView.swift
//  ToneCurveEditor
//
//  Created by Sun on 2026/02/10.
//

import UIKit

public enum ToneCurveEditorDragPreset: Int, CaseIterable, Sendable {
    case precision
    case easy
}

public final class ToneCurveEditorView: UIControl {
    public var curveSet: ToneCurveSet = .identity {
        didSet {
            refreshAllLayers()
        }
    }

    public var activeChannel: ToneCurveChannel = .master {
        didSet {
            refreshAllLayers()
        }
    }

    public var allowsPointInsertion = false
    public var allowsPointRemoval = false
    public var lockEndpoints = true
    public var xEpsilon: Float = 0.001

    public var plotInsets: UIEdgeInsets = .init(top: 20, left: 20, bottom: 20, right: 20) {
        didSet {
            setNeedsLayout()
        }
    }

    public var pointRadius: CGFloat = 6 {
        didSet {
            refreshControlPointsLayer()
        }
    }

    // Keep touch target large enough for stable drag interactions.
    public var pointTouchTargetSize: CGFloat = 44 {
        didSet {
            pointTouchTargetSize = max(22, pointTouchTargetSize)
        }
    }

    // Dragging point keeps same style and scales up visually.
    public var draggingPointScale: CGFloat = 1.45 {
        didSet {
            draggingPointScale = max(1, draggingPointScale)
            refreshControlPointsLayer()
        }
    }

    public var dragInteractionPreset: ToneCurveEditorDragPreset = .easy {
        didSet {
            applyDragInteractionPreset()
        }
    }

    // Diagonal guide line rendered under all curves (default: y = x).
    public var showsReferenceLine = true {
        didSet {
            refreshReferenceLineLayer()
        }
    }

    public var referenceLineColor: UIColor = .systemGray.withAlphaComponent(0.7) {
        didSet {
            refreshReferenceLineLayer()
        }
    }

    public var referenceLineWidth: CGFloat = 1 {
        didSet {
            refreshReferenceLineLayer()
        }
    }

    public var referenceLineStartPoint: ToneCurvePoint = .init(x: 0, y: 0) {
        didSet {
            refreshReferenceLineLayer()
        }
    }

    public var referenceLineEndPoint: ToneCurvePoint = .init(x: 1, y: 1) {
        didSet {
            refreshReferenceLineLayer()
        }
    }

    override public var intrinsicContentSize: CGSize {
        CGSize(width: 320, height: 260)
    }

    private let referenceLineLayer = CAShapeLayer()
    private let gridLayer = CAShapeLayer()
    private let controlPointsLayer = CAShapeLayer()
    private let highlightedPointLayer = CAShapeLayer()
    private var channelLayers: [ToneCurveChannel: CAShapeLayer] = [:]

    private lazy var panGesture = UIPanGestureRecognizer(
        target: self,
        action: #selector(handlePan(_:))
    )
    private lazy var tapGesture = UITapGestureRecognizer(
        target: self,
        action: #selector(handleTap(_:))
    )
    private lazy var longPressGesture = UILongPressGestureRecognizer(
        target: self,
        action: #selector(handleLongPress(_:))
    )

    private var draggingPointIndex: Int?

    override public init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        refreshAllLayers()
    }

    override public func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle {
            refreshAllLayers()
        }
    }

    private func commonInit() {
        isMultipleTouchEnabled = false
        backgroundColor = .clear

        referenceLineLayer.fillColor = UIColor.clear.cgColor
        referenceLineLayer.lineCap = .round
        referenceLineLayer.lineJoin = .round
        referenceLineLayer.contentsScale = UIScreen.main.scale
        layer.insertSublayer(referenceLineLayer, at: 0)

        gridLayer.fillColor = UIColor.clear.cgColor
        gridLayer.strokeColor = UIColor.systemGray.withAlphaComponent(0.55).cgColor
        gridLayer.lineWidth = 0.7
        layer.insertSublayer(gridLayer, at: 1)

        for channel in ToneCurveChannel.allCases {
            let curveLayer = CAShapeLayer()
            curveLayer.fillColor = UIColor.clear.cgColor
            curveLayer.lineCap = .round
            curveLayer.lineJoin = .round
            curveLayer.contentsScale = UIScreen.main.scale
            channelLayers[channel] = curveLayer
            layer.addSublayer(curveLayer)
        }

        controlPointsLayer.fillColor = UIColor.clear.cgColor
        controlPointsLayer.strokeColor = UIColor.clear.cgColor
        controlPointsLayer.lineWidth = 0
        controlPointsLayer.contentsScale = UIScreen.main.scale
        layer.addSublayer(controlPointsLayer)

        highlightedPointLayer.fillColor = UIColor.clear.cgColor
        highlightedPointLayer.strokeColor = UIColor.clear.cgColor
        highlightedPointLayer.lineWidth = 0
        highlightedPointLayer.contentsScale = UIScreen.main.scale
        layer.addSublayer(highlightedPointLayer)

        panGesture.maximumNumberOfTouches = 1
        addGestureRecognizer(panGesture)
        addGestureRecognizer(tapGesture)
        addGestureRecognizer(longPressGesture)

        applyDragInteractionPreset()
        refreshAllLayers()
    }

    private func applyDragInteractionPreset() {
        switch dragInteractionPreset {
        case .precision:
            pointTouchTargetSize = 40
            draggingPointScale = 1.3
            xEpsilon = 0.001_5
        case .easy:
            pointTouchTargetSize = 56
            draggingPointScale = 1.6
            xEpsilon = 0.000_5
        }
    }

    private var plotRect: CGRect {
        bounds.inset(by: plotInsets)
    }

    private var activePoints: [ToneCurvePoint] {
        curveSet[activeChannel].points
    }

    private func refreshAllLayers() {
        refreshReferenceLineLayer()
        refreshGridLayer()
        refreshCurveLayers()
        refreshControlPointsLayer()
    }

    private func refreshReferenceLineLayer() {
        let rect = plotRect
        guard showsReferenceLine, rect.width > 0, rect.height > 0 else {
            referenceLineLayer.path = nil
            return
        }

        let start = ToneCurveEditorGeometry.viewPoint(from: referenceLineStartPoint.clamped, in: rect)
        let end = ToneCurveEditorGeometry.viewPoint(from: referenceLineEndPoint.clamped, in: rect)

        let path = UIBezierPath()
        path.move(to: start)
        path.addLine(to: end)

        referenceLineLayer.path = path.cgPath
        referenceLineLayer.strokeColor = referenceLineColor.cgColor
        referenceLineLayer.lineWidth = max(0.5, referenceLineWidth)
    }

    private func refreshGridLayer() {
        let rect = plotRect
        guard rect.width > 0, rect.height > 0 else {
            gridLayer.path = nil
            return
        }

        let path = UIBezierPath(rect: rect)
        let steps = 4

        for index in 0...steps {
            let t = CGFloat(index) / CGFloat(steps)
            let x = rect.minX + t * rect.width
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))

            let y = rect.minY + t * rect.height
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
        }

        gridLayer.path = path.cgPath
    }

    private func refreshCurveLayers() {
        let rect = plotRect
        guard rect.width > 0, rect.height > 0 else {
            for layer in channelLayers.values {
                layer.path = nil
            }
            return
        }

        for channel in ToneCurveChannel.allCases {
            guard let layer = channelLayers[channel] else {
                continue
            }

            let curve = curveSet[channel]
            layer.path = ToneCurvePathBuilder.makePath(for: curve, in: rect)
            layer.strokeColor = color(for: channel).cgColor
            layer.lineWidth = channel == activeChannel ? 3 : 2
            layer.opacity = channel == activeChannel ? 1 : 0.35
        }
    }

    private func refreshControlPointsLayer() {
        let rect = plotRect
        guard rect.width > 0, rect.height > 0 else {
            controlPointsLayer.path = nil
            highlightedPointLayer.path = nil
            return
        }

        let pointsPath = UIBezierPath()
        let activeCurvePoints = activePoints
        let color = color(for: activeChannel)

        for point in activeCurvePoints {
            let center = ToneCurveEditorGeometry.viewPoint(from: point, in: rect)
            let pointRect = CGRect(
                x: center.x - pointRadius,
                y: center.y - pointRadius,
                width: pointRadius * 2,
                height: pointRadius * 2
            )
            pointsPath.append(UIBezierPath(ovalIn: pointRect))
        }

        controlPointsLayer.path = pointsPath.cgPath
        controlPointsLayer.strokeColor = UIColor.clear.cgColor
        controlPointsLayer.fillColor = color.cgColor

        if let draggingPointIndex, activeCurvePoints.indices.contains(draggingPointIndex) {
            let point = activeCurvePoints[draggingPointIndex]
            let center = ToneCurveEditorGeometry.viewPoint(from: point, in: rect)
            let radius = pointRadius * draggingPointScale
            let highlightedRect = CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            )
            highlightedPointLayer.path = UIBezierPath(ovalIn: highlightedRect).cgPath
            highlightedPointLayer.strokeColor = UIColor.clear.cgColor
            highlightedPointLayer.fillColor = color.cgColor
        } else {
            highlightedPointLayer.path = nil
        }
    }

    private func color(for channel: ToneCurveChannel) -> UIColor {
        switch channel {
        case .master:
            .white
        case .red:
            .systemRed
        case .green:
            .systemGreen
        case .blue:
            .systemBlue
        }
    }

    private var pointHitDistance: CGFloat {
        max(pointRadius * 2.5, pointTouchTargetSize * 0.5)
    }

    @objc
    private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: self)
        let rect = plotRect

        switch gesture.state {
        case .began:
            guard
                let hitIndex = ToneCurveEditorGeometry.nearestPointIndex(
                    to: location,
                    points: activePoints,
                    in: rect,
                    maxDistance: pointHitDistance
                )
            else {
                return
            }

            draggingPointIndex = hitIndex
            refreshControlPointsLayer()
            sendActions(for: .editingDidBegin)

        case .changed:
            guard let draggingPointIndex else {
                return
            }

            var points = activePoints
            let candidate = ToneCurveEditorGeometry.normalizedPoint(from: location, in: rect)
            let constrained = ToneCurveEditorGeometry.constrainedDragPoint(
                candidate: candidate,
                at: draggingPointIndex,
                points: points,
                lockEndpoints: lockEndpoints,
                xEpsilon: xEpsilon
            )

            let old = points[draggingPointIndex]
            if abs(old.x - constrained.x) < 0.000_001, abs(old.y - constrained.y) < 0.000_001 {
                return
            }

            points[draggingPointIndex] = constrained
            updateActiveCurve(points: points, emitValueChanged: true)

        case .ended, .cancelled, .failed:
            if draggingPointIndex != nil {
                draggingPointIndex = nil
                refreshControlPointsLayer()
                sendActions(for: .editingDidEnd)
            }

        default:
            break
        }
    }

    @objc
    private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard allowsPointInsertion else {
            return
        }

        var points = activePoints
        if points.count >= 17 {
            return
        }

        let candidate = ToneCurveEditorGeometry.normalizedPoint(
            from: gesture.location(in: self),
            in: plotRect
        )

        guard let insertIndex = points.firstIndex(where: { $0.x > candidate.x }), insertIndex > 0 else {
            return
        }

        let left = points[insertIndex - 1]
        let right = points[insertIndex]
        if candidate.x <= left.x + xEpsilon || candidate.x >= right.x - xEpsilon {
            return
        }

        points.insert(candidate, at: insertIndex)
        updateActiveCurve(points: points, emitValueChanged: true)
    }

    @objc
    private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard allowsPointRemoval, gesture.state == .began else {
            return
        }

        var points = activePoints
        if points.count <= 3 {
            return
        }

        guard
            let hitIndex = ToneCurveEditorGeometry.nearestPointIndex(
                to: gesture.location(in: self),
                points: points,
                in: plotRect,
                maxDistance: pointHitDistance
            ) else {
            return
        }

        if hitIndex == 0 || hitIndex == points.count - 1 {
            return
        }

        points.remove(at: hitIndex)
        updateActiveCurve(points: points, emitValueChanged: true)
    }

    private func updateActiveCurve(points: [ToneCurvePoint], emitValueChanged: Bool) {
        guard let curve = try? ToneCurve(points: points) else {
            return
        }

        var next = curveSet
        next[activeChannel] = curve
        curveSet = next

        if emitValueChanged {
            sendActions(for: .valueChanged)
        }
    }
}
