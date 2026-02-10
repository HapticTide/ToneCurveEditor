//
//  PreviewView.swift
//  ToneCurveEditor
//
//  Created by Sun on 2026/02/10.
//

import UIKit

final class PreviewView: UIView {
    var originalImage: UIImage? {
        didSet {
            originalImageView.image = originalImage
        }
    }

    var processedImage: UIImage? {
        didSet {
            processedImageView.image = processedImage
        }
    }

    private let originalImageView = UIImageView()
    private let processedImageView = UIImageView()
    private let originalTitleLabel = UILabel()
    private let processedTitleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
}

private extension PreviewView {
    func setupUI() {
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 12
        layer.masksToBounds = true

        originalTitleLabel.text = "Original"
        processedTitleLabel.text = "Processed"

        for label in [originalTitleLabel, processedTitleLabel] {
            label.font = .preferredFont(forTextStyle: .footnote)
            label.textAlignment = .center
            label.textColor = .secondaryLabel
        }

        for imageView in [originalImageView, processedImageView] {
            imageView.contentMode = .scaleAspectFit
            imageView.backgroundColor = .black
            imageView.layer.cornerRadius = 8
            imageView.layer.masksToBounds = true
            imageView.translatesAutoresizingMaskIntoConstraints = false
        }

        let originalStack = UIStackView(arrangedSubviews: [originalTitleLabel, originalImageView])
        originalStack.axis = .vertical
        originalStack.spacing = 8

        let processedStack = UIStackView(arrangedSubviews: [processedTitleLabel, processedImageView])
        processedStack.axis = .vertical
        processedStack.spacing = 8

        let contentStack = UIStackView(arrangedSubviews: [originalStack, processedStack])
        contentStack.axis = .horizontal
        contentStack.spacing = 12
        contentStack.distribution = .fillEqually
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(contentStack)

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            contentStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),

            originalImageView.heightAnchor.constraint(greaterThanOrEqualToConstant: 140),
            processedImageView.heightAnchor.constraint(greaterThanOrEqualToConstant: 140),
        ])
    }
}
