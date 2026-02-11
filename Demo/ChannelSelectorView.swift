//
//  ChannelSelectorView.swift
//  ToneCurveEditor
//
//  Created by Sun on 2026/02/10.
//

import ToneCurveEditor
import UIKit

final class ChannelSelectorView: UIView {
    private static let iconPointSize: CGFloat = 22

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
    private let masterIcon = ChannelSelectorView.makeMasterAssetIcon(
        pointSize: ChannelSelectorView.iconPointSize
    )
    private let solidDiskIcon = ChannelSelectorView.makeSolidDiskIcon(
        diameter: ChannelSelectorView.iconPointSize
    )
    private let selectionIndicator = UIView()
    private var selectionIndicatorCenterYConstraint: NSLayoutConstraint?

    override var intrinsicContentSize: CGSize {
        CGSize(width: 44, height: UIView.noIntrinsicMetric)
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
        resetButton.configuration?.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(
            pointSize: 18,
            weight: .semibold
        )
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
            buttonsStack.centerXAnchor.constraint(equalTo: centerXAnchor),
            buttonsStack.centerYAnchor.constraint(equalTo: centerYAnchor),
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
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(
            pointSize: Self.iconPointSize,
            weight: .semibold
        )
        config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 8, bottom: 10, trailing: 8)
        return config
    }

    func icon(for channel: ToneCurveChannel) -> UIImage? {
        switch channel {
        case .master:
            masterIcon
        case .red:
            solidDiskIcon
        case .green:
            solidDiskIcon
        case .blue:
            solidDiskIcon
        }
    }

    static func makeSolidDiskIcon(diameter: CGFloat) -> UIImage {
        let size = CGSize(width: diameter, height: diameter)
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = max(UIScreen.main.scale, 3) * 2

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { context in
            let cg = context.cgContext
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: 0.4, dy: 0.4)
            cg.setFillColor(UIColor.white.cgColor)
            cg.fillEllipse(in: rect)
        }
        return image.withRenderingMode(.alwaysTemplate)
    }

    static func makeMasterAssetIcon(pointSize: CGFloat) -> UIImage? {
        guard let assetImage = UIImage(named: "master") else {
            return nil
        }

        let size = CGSize(width: pointSize, height: pointSize)
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = max(UIScreen.main.scale, 3)

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { _ in
            assetImage.draw(in: CGRect(origin: .zero, size: size))
        }
        return image.withRenderingMode(.alwaysOriginal)
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
            button.transform = .identity
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
