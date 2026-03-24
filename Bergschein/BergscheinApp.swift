//
//  BergscheinApp.swift
//  Bergschein
//
//  Created by Florian Werner on 20.03.26.
//

import SwiftUI
#if os(iOS)
import CoreText
import UIKit
import UserNotifications
#endif

enum BrandFont {
    static let fallbackName = "Georgia-Bold"
    static var primaryName = fallbackName
}

enum BrandColor {
    static let darkForest = UIColor(red: 0.169, green: 0.227, blue: 0.184, alpha: 1.0)
    static let navigationTitle = UIColor { traitCollection in
        if traitCollection.userInterfaceStyle == .dark {
            return UIColor(red: 0.92, green: 0.97, blue: 0.93, alpha: 1.0)
        }

        return darkForest
    }
}

enum NotificationDestination: String {
    case challenge
}

extension Notification.Name {
    static let bergscheinOpenNotificationDestination = Notification.Name("bergscheinOpenNotificationDestination")
}

@MainActor
final class NotificationNavigationStore {
    static let shared = NotificationNavigationStore()

    private(set) var pendingDestination: NotificationDestination?

    func handle(userInfo: [AnyHashable: Any]) {
        guard let rawValue = userInfo["destination"] as? String,
              let destination = NotificationDestination(rawValue: rawValue) else {
            return
        }

        pendingDestination = destination
        NotificationCenter.default.post(name: .bergscheinOpenNotificationDestination, object: destination)
    }

    func consumePendingDestination() -> NotificationDestination? {
        defer { pendingDestination = nil }
        return pendingDestination
    }
}

#if os(iOS)
final class BergscheinNotificationDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        await MainActor.run {
            NotificationNavigationStore.shared.handle(userInfo: response.notification.request.content.userInfo)
        }
    }
}
#endif

@main
struct BergscheinApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(BergscheinNotificationDelegate.self) private var notificationDelegate
    #endif

    init() {
        configureNavigationTitleAppearance()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    private func configureNavigationTitleAppearance() {
        #if os(iOS)
        guard let customFontName = registerFont(named: "font", extension: "ttf") else {
            return
        }
        BrandFont.primaryName = customFontName

        let accentColor = UIColor(red: 0.153, green: 0.514, blue: 0.216, alpha: 1.0)

        let inlineFont = UIFont(name: customFontName, size: 17) ?? .systemFont(ofSize: 17, weight: .semibold)
        let largeFont = UIFont(name: customFontName, size: 34) ?? .boldSystemFont(ofSize: 34)

        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.titleTextAttributes = [
            .font: inlineFont,
            .foregroundColor: BrandColor.navigationTitle
        ]
        appearance.largeTitleTextAttributes = [
            .font: largeFont,
            .foregroundColor: BrandColor.navigationTitle
        ]

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().tintColor = accentColor
        UITabBar.appearance().tintColor = accentColor
        UIView.appearance().tintColor = accentColor
        #endif
    }

    #if os(iOS)
    private func registerFont(named name: String, extension fileExtension: String) -> String? {
        guard let url = Bundle.main.url(forResource: name, withExtension: fileExtension) else {
            return nil
        }

        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)

        guard
            let provider = CGDataProvider(url: url as CFURL),
            let font = CGFont(provider)
        else {
            return nil
        }

        return font.postScriptName as String?
    }
    #endif
}
