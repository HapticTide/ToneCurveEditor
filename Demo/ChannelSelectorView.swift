//
//  ChannelSelectorView.swift
//  ToneCurveEditor
//
//  Created by Sun on 2026/02/10.
//

import ToneCurveEditor
import UIKit

final class ChannelSelectorView: UIView {
    var onChannelChanged: ((ToneCurveChannel) -> Void)?
    var onResetTapped: (() -> Void)?

    var selectedChannel: ToneCurveChannel {
        didSet {
            updateButtonStyles()
        }
    }

    private let buttonsStack = UIStackView()
    private let channels: [ToneCurveChannel] = [.master, .red, .green, .blue]
    private var buttonsByChannel: [ToneCurveChannel: UIButton] = [:]
    private let resetButton = UIButton(type: .system)
    private let masterWheelIcon = ChannelSelectorView.makeMasterWheelIcon(diameter: 18)
    private let selectionIndicator = UIView()
    private var selectionIndicatorCenterYConstraint: NSLayoutConstraint?

    override var intrinsicContentSize: CGSize {
        CGSize(width: 50, height: UIView.noIntrinsicMetric)
    }

    override init(frame: CGRect) {
        selectedChannel = .master
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        selectedChannel = .master
        super.init(coder: coder)
        setupUI()
    }
}

private extension ChannelSelectorView {
    func setupUI() {
        buttonsStack.axis = .vertical
        buttonsStack.spacing = 6
        buttonsStack.alignment = .center
        buttonsStack.distribution = .fill

        for channel in channels {
            let button = makeChannelButton(for: channel)
            buttonsByChannel[channel] = button
            buttonsStack.addArrangedSubview(button)

            button.widthAnchor.constraint(equalToConstant: 34).isActive = true
            button.heightAnchor.constraint(equalToConstant: 40).isActive = true
        }

        resetButton.configuration = makeButtonConfiguration(
            backgroundColor: .clear,
            imageColor: UIColor.secondaryLabel
        )
        resetButton.configuration?.image = UIImage(systemName: "arrow.counterclockwise")
        resetButton.layer.cornerRadius = 10
        resetButton.layer.masksToBounds = true
        resetButton.addAction(
            UIAction { [weak self] _ in
                self?.onResetTapped?()
            },
            for: .touchUpInside
        )
        buttonsStack.addArrangedSubview(resetButton)
        resetButton.widthAnchor.constraint(equalToConstant: 34).isActive = true
        resetButton.heightAnchor.constraint(equalToConstant: 40).isActive = true

        buttonsStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(buttonsStack)
        NSLayoutConstraint.activate([
            buttonsStack.topAnchor.constraint(equalTo: topAnchor),
            buttonsStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            buttonsStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            buttonsStack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        selectionIndicator.backgroundColor = .systemOrange
        selectionIndicator.layer.cornerRadius = 2
        selectionIndicator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(selectionIndicator)
        selectionIndicatorCenterYConstraint = selectionIndicator.centerYAnchor.constraint(
            equalTo: buttonsByChannel[selectedChannel]?.centerYAnchor ?? buttonsStack.centerYAnchor
        )
        selectionIndicatorCenterYConstraint?.isActive = true
        NSLayoutConstraint.activate([
            selectionIndicator.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 1),
            selectionIndicator.widthAnchor.constraint(equalToConstant: 4),
            selectionIndicator.heightAnchor.constraint(equalToConstant: 22),
        ])

        updateButtonStyles()
    }

    func makeChannelButton(for channel: ToneCurveChannel) -> UIButton {
        let button = UIButton(type: .system)
        button.layer.cornerRadius = 10
        button.layer.masksToBounds = true
        button.configuration = makeButtonConfiguration(
            backgroundColor: .clear,
            imageColor: color(for: channel).withAlphaComponent(0.9)
        )
        button.configuration?.image = icon(for: channel)
        button.addAction(
            UIAction { [weak self] _ in
                self?.channelTapped(channel)
            },
            for: .touchUpInside
        )
        return button
    }

    func channelTapped(_ channel: ToneCurveChannel) {
        if selectedChannel == channel {
            return
        }
        selectedChannel = channel
        onChannelChanged?(selectedChannel)
    }

    func makeButtonConfiguration(backgroundColor: UIColor, imageColor: UIColor) -> UIButton.Configuration {
        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = backgroundColor
        config.baseForegroundColor = imageColor
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)
        return config
    }

    func icon(for channel: ToneCurveChannel) -> UIImage? {
        switch channel {
        case .master:
            masterWheelIcon
        case .red:
            UIImage(systemName: "circle.fill")
        case .green:
            UIImage(systemName: "circle.fill")
        case .blue:
            UIImage(systemName: "circle.fill")
        }
    }

    static func makeMasterWheelIcon(diameter: CGFloat) -> UIImage {
        let size = CGSize(width: diameter, height: diameter)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let cg = context.cgContext
            let rect = CGRect(origin: .zero, size: size)
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let radius = diameter * 0.5
            let segments = 180

            cg.saveGState()
            cg.addEllipse(in: rect)
            cg.clip()

            for index in 0..<segments {
                let start = (CGFloat(index) / CGFloat(segments)) * .pi * 2
                let end = (CGFloat(index + 1) / CGFloat(segments)) * .pi * 2
                let hue = CGFloat(index) / CGFloat(segments)

                cg.move(to: center)
                cg.addArc(
                    center: center,
                    radius: radius,
                    startAngle: start,
                    endAngle: end,
                    clockwise: false
                )
                cg.closePath()
                cg.setFillColor(UIColor(hue: hue, saturation: 1, brightness: 1, alpha: 1).cgColor)
                cg.fillPath()
            }

            let colors = [
                UIColor.white.withAlphaComponent(0.95).cgColor,
                UIColor.white.withAlphaComponent(0).cgColor,
            ] as CFArray
            let locations: [CGFloat] = [0, 0.82]
            if
                let gradient = CGGradient(
                    colorsSpace: CGColorSpaceCreateDeviceRGB(),
                    colors: colors,
                    locations: locations
                ) {
                cg.drawRadialGradient(
                    gradient,
                    startCenter: center,
                    startRadius: 0,
                    endCenter: center,
                    endRadius: radius,
                    options: []
                )
            }
            cg.restoreGState()

            cg.setStrokeColor(UIColor.white.withAlphaComponent(0.45).cgColor)
            cg.setLineWidth(0.7)
            cg.strokeEllipse(in: rect.insetBy(dx: 0.35, dy: 0.35))
        }
        .withRenderingMode(.alwaysOriginal)
    }

    func color(for channel: ToneCurveChannel) -> UIColor {
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

    func updateButtonStyles() {
        for channel in channels {
            guard let button = buttonsByChannel[channel] else {
                continue
            }

            let accent = color(for: channel)
            let isSelected = selectedChannel == channel

            var config = button.configuration ?? UIButton.Configuration.plain()
            config.baseBackgroundColor = .clear
            config.baseForegroundColor = accent.withAlphaComponent(isSelected ? 1 : 0.62)
            button.alpha = isSelected ? 1 : 0.72
            button.transform = isSelected ? CGAffineTransform(scaleX: 1.1, y: 1.1) : .identity
            button.configuration = config
        }

        if let selectedButton = buttonsByChannel[selectedChannel] {
            selectionIndicatorCenterYConstraint?.isActive = false
            selectionIndicatorCenterYConstraint = selectionIndicator.centerYAnchor.constraint(
                equalTo: selectedButton.centerYAnchor
            )
            selectionIndicatorCenterYConstraint?.isActive = true
        }

        var resetConfig = resetButton.configuration ?? UIButton.Configuration.plain()
        resetConfig.baseBackgroundColor = .clear
        resetConfig.baseForegroundColor = UIColor.secondaryLabel
        resetButton.configuration = resetConfig

        UIView.animate(withDuration: 0.18) {
            self.layoutIfNeeded()
        }
    }
}
