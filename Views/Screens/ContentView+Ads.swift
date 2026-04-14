import SwiftUI

extension ContentView {
    var currentAdBanner: AdBanner {
        let slot = currentAdSlot
        let isSpecialDay = isWeekendOrSpecialBannerDay
        let isInsideRegion = locationController.isInAllowedRegion

        switch (isInsideRegion, isSpecialDay, slot) {
        case (_, _, .automatic):
            return .ffwd
        case (false, _, .morning):
            switch morningOutsideBannerVariant {
            case .ffwd:
                return .ffwd
            case .ching:
                return .ching
            case .tb:
                return .tb
            case .fresh:
                return .ffwd
            }
        case (false, _, .afternoon):
            switch morningOutsideBannerVariant {
            case .ffwd:
                return .ffwd
            case .ching:
                return .ching
            case .tb:
                return .tb
            case .fresh:
                return .fresh
            }
        case (false, _, .overnight):
            return .zirkel
        case (true, false, .morning):
            return .ffwd
        case (true, false, .afternoon):
            return .erich
        case (true, false, .overnight):
            return .zirkel
        case (true, true, .morning), (true, true, .afternoon):
            return .erich
        case (true, true, .overnight):
            return .zirkel
        }
    }

    var currentAdSlot: AdSlotOverride {
        switch adSlotOverride {
        case .automatic:
            break
        case .morning, .afternoon, .overnight:
            return adSlotOverride
        }

        let hour = Calendar.current.component(.hour, from: currentDate)
        if hour >= 6 && hour < 15 {
            return .morning
        }
        if hour >= 15 && hour < 23 {
            return .afternoon
        }
        return .overnight
    }

    var isWeekendOrSpecialBannerDay: Bool {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: currentDate)
        let month = calendar.component(.month, from: currentDate)
        let day = calendar.component(.day, from: currentDate)

        let isWeekend = weekday == 1 || weekday == 7
        let isSpecialDate = month == 5 && day == 25

        return isWeekend || isSpecialDate
    }

    func refreshMorningOutsideBannerVariant() {
        guard (currentAdSlot == .morning || currentAdSlot == .afternoon), !locationController.isInAllowedRegion else {
            morningOutsideBannerVariant = .ffwd
            return
        }

        let randomValue = Int.random(in: 1...10)
        if currentAdSlot == .morning {
            switch randomValue {
            case 1...4:
                morningOutsideBannerVariant = .ffwd
            case 5...8:
                morningOutsideBannerVariant = .ching
            default:
                morningOutsideBannerVariant = .tb
            }
        } else {
            switch randomValue {
            case 1...3:
                morningOutsideBannerVariant = .ffwd
            case 4...6:
                morningOutsideBannerVariant = .ching
            case 7...8:
                morningOutsideBannerVariant = .tb
            default:
                morningOutsideBannerVariant = .fresh
            }
        }
    }

    func handleFFWDLogoTap() {
        guard !isDebugMenuUnlocked else { return }

        ffwdLogoTapCount += 1
        if ffwdLogoTapCount >= 10 {
            isDebugMenuUnlocked = true
            ffwdLogoTapCount = 0
            triggerSuccessHaptic()
        }
    }
}
