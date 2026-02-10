//
//  ImagePickerCoordinator.swift
//  ToneCurveEditor
//
//  Created by Sun on 2026/02/10.
//

import PhotosUI
import UIKit

final class ImagePickerCoordinator: NSObject {
    var onImagePicked: ((UIImage) -> Void)?
}

extension ImagePickerCoordinator {
    func presentPicker(from viewController: UIViewController) {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.selectionLimit = 1
        configuration.filter = .images
        configuration.preferredAssetRepresentationMode = .current

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        viewController.present(picker, animated: true)
    }
}

extension ImagePickerCoordinator: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)

        guard let provider = results.first?.itemProvider else {
            return
        }

        if provider.canLoadObject(ofClass: UIImage.self) {
            provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
                guard let image = object as? UIImage else {
                    return
                }
                DispatchQueue.main.async {
                    self?.onImagePicked?(image)
                }
            }
        }
    }
}
