import CoreLocation
import SwiftUI

extension ContentView {
    var statusGradient: LinearGradient {
        LinearGradient(
            colors: statusGradientColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var appBackgroundGradient: LinearGradient {
        LinearGradient(
            colors: appBackgroundColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var darkForest: Color {
        colorScheme == .dark ? Color(uiColor: .label) : Color(red: 0.169, green: 0.227, blue: 0.184)
    }

    var appBackgroundColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(uiColor: .systemBackground),
                Color.accentColor.opacity(0.14),
                Color(uiColor: .secondarySystemBackground)
            ]
        }

        return [Color(.systemGray6), Color.accentColor.opacity(0.10)]
    }

    var onboardingBackgroundColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(uiColor: .systemBackground),
                Color.accentColor.opacity(0.22),
                Color(uiColor: .secondarySystemBackground)
            ]
        }

        return [Color(.systemGray6), Color.accentColor.opacity(0.18)]
    }

    var statusGradientColors: [Color] {
        if hasEventEnded {
            return [
                Color(.systemGray5),
                Color(.systemGray4)
            ]
        }
        if !hasOfficialOpeningStarted {
            return [
                Color(.systemGray5),
                Color.accentColor.opacity(0.18)
            ]
        }
        if isCurrentBadgeUnlocked {
            return [Color(red: 0.12, green: 0.39, blue: 0.19), Color(red: 0.24, green: 0.60, blue: 0.31)]
        }
        if !locationController.isInAllowedRegion {
            return [Color(red: 0.72, green: 0.24, blue: 0.22), Color(red: 0.86, green: 0.42, blue: 0.32)]
        }
        return [
            Color(.systemGray5),
            Color.accentColor.opacity(0.18)
        ]
    }

    var cardGradientBaseColor: Color {
        if isCurrentBadgeUnlocked {
            return statusGradientColors.first ?? .accentColor
        }
        if !locationController.isInAllowedRegion {
            return statusGradientColors.first ?? .red
        }
        return .accentColor
    }

    var statusForegroundColor: Color {
        if hasEventEnded {
            return darkForest
        }
        if !hasOfficialOpeningStarted {
            return darkForest
        }
        if isCurrentBadgeUnlocked || !locationController.isInAllowedRegion {
            return .white
        }
        return darkForest
    }

    var stampStatusSymbol: String {
        if hasEventEnded {
            return "moon.zzz.fill"
        }
        if !hasOfficialOpeningStarted {
            return "timer"
        }
        if isCurrentBadgeUnlocked {
            return "checkmark.seal.fill"
        }
        if canClaimToday {
            return "seal.fill"
        }
        return "mountain.2.fill"
    }

    var stampStatusColor: Color {
        if isCurrentBadgeUnlocked {
            return .accentColor
        }
        if canClaimToday {
            return .accentColor
        }
        return .secondary
    }

    var shouldShowDistanceHint: Bool {
        !locationController.isInAllowedRegion || locationController.distanceToRegionMeters.map { $0 > 50 } == true
    }

    var locationPermissionWarningText: String? {
        guard locationController.authorizationStatus == .denied || locationController.authorizationStatus == .restricted else {
            return nil
        }
        return "Standortzugriff fehlt. Bitte aktiviere ihn in den Einstellungen, damit du am Berg einchecken kannst."
    }
}
