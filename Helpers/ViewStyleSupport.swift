//
//  ViewStyleSupport.swift
//  Bergschein
//

import SwiftUI
import UIKit

let overlayCardTransition = AnyTransition.asymmetric(
    insertion: .opacity
        .combined(with: .scale(scale: 0.90, anchor: .center))
        .combined(with: .offset(y: 18)),
    removal: .opacity
        .combined(with: .scale(scale: 0.96, anchor: .center))
)

extension Color {
    static let appCardBackground = Color(uiColor: .secondarySystemBackground)
    static let appElevatedBackground = Color(uiColor: .tertiarySystemBackground)
    static let appSoftStroke = Color.primary.opacity(0.10)
    static let appSoftShadow = Color.black.opacity(0.14)
    static let appWarningTint = Color(red: 0.72, green: 0.21, blue: 0.18)
    static let appWarningText = Color(red: 0.48, green: 0.10, blue: 0.10)
    static let appWarningBackground = Color.appWarningTint.opacity(0.14)
    static let adCardBackground = Color(
        uiColor: UIColor { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor(red: 0.10, green: 0.13, blue: 0.11, alpha: 1.0)
            }

            return UIColor(red: 0.97, green: 0.985, blue: 0.972, alpha: 1.0)
        }
    )
}

func loadBadgeUIImage(named imageName: String) -> UIImage? {
    loadBundleUIImage(named: imageName)
}

func loadBundleUIImage(named imageName: String) -> UIImage? {
    if let assetImage = UIImage(named: imageName) {
        return assetImage
    }

    guard let url = Bundle.main.url(forResource: imageName, withExtension: "png") else {
        return nil
    }

    return UIImage(contentsOfFile: url.path)
}
