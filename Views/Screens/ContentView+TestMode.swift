import MapKit
import SwiftUI

extension ContentView {
    var isTestModeActive: Bool {
        useSimulatedDate || locationController.isUsingTestRegion || adSlotOverride != .automatic
    }

    var formattedCurrentDate: String {
        let displayDate = useSimulatedDate ? currentDate : Date()
        return displayDate.formatted(date: .abbreviated, time: .shortened)
    }

    var hasSimulatedTimeOverride: Bool {
        simulatedTimeMinutes >= 0
    }

    var simulatedTimeDisplayText: String {
        guard hasSimulatedTimeOverride else {
            return "Systemzeit"
        }
        let hour = simulatedTimeMinutes / 60
        let minute = simulatedTimeMinutes % 60
        return String(format: "%02d:%02d Uhr", hour, minute)
    }

    var simulatedTimePickerDate: Date {
        let calendar = Calendar.current
        let now = Date()
        guard hasSimulatedTimeOverride else {
            return now
        }

        let hour = simulatedTimeMinutes / 60
        let minute = simulatedTimeMinutes % 60
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = minute
        components.second = 0
        return calendar.date(from: components) ?? now
    }

    func simulatedTimeSource(from liveDate: Date) -> Date {
        guard hasSimulatedTimeOverride else {
            return liveDate
        }

        let calendar = Calendar.current
        let hour = simulatedTimeMinutes / 60
        let minute = simulatedTimeMinutes % 60
        var components = calendar.dateComponents([.year, .month, .day], from: liveDate)
        components.hour = hour
        components.minute = minute
        components.second = 0
        return calendar.date(from: components) ?? liveDate
    }

    func setSimulatedTime(from pickerDate: Date) {
        let components = Calendar.current.dateComponents([.hour, .minute], from: pickerDate)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        simulatedTimeMinutes = (hour * 60) + minute

        if useSimulatedDate {
            currentDate = simulatedDate(for: currentDate, usingTimeFrom: simulatedTimeSource(from: Date()))
            evaluateMissedDayNotice()
        }
    }

    func resetSimulatedTimeToSystem() {
        simulatedTimeMinutes = -1

        if useSimulatedDate {
            currentDate = simulatedDate(for: currentDate, usingTimeFrom: Date())
            evaluateMissedDayNotice()
        }
    }

    func simulatedDate(for targetDate: Date, usingTimeFrom timeSource: Date) -> Date {
        BergscheinDateHelper.mergedDate(day: targetDate, timeSource: timeSource)
    }

    func goToNextDay() {
        ensureTestEventStartDay()

        if !useSimulatedDate {
            useSimulatedDate = true
            currentDate = defaultEventStartDate.map { simulatedDate(for: $0, usingTimeFrom: simulatedTimeSource(from: Date())) } ?? currentDate
            evaluateMissedDayNotice()
            return
        }

        useSimulatedDate = true
        currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        evaluateMissedDayNotice()
    }

    func resetProgress() {
        unlockedBadgeIdentifiers = ""
        completedChallengeIdentifiers = ""
        tbDrinkRewardUnlocked = false
        tbDrinkRewardRedeemed = false
        zirkelRewardUnlocked = false
        zirkelRewardRedeemed = false
        bibOfferRewardUnlocked = false
        bibOfferRewardRedeemed = false
        testEventStartDay = ""
        withAnimation(overlayDismissAnimation) {
            activeBadgeOverlay = nil
            activeChallengeRewardOverlay = nil
            activeMissedDayAlert = nil
        }
        dismissedMissedBadgeIdentifier = ""
        adSlotOverride = .automatic
        simulatedTimeMinutes = -1
        useSimulatedDate = false
        syncCurrentDate()
        locationController.clearTestRegion()
        locationController.requestLocationAccess()
    }

    func deactivateTestMode() {
        isDebugMenuUnlocked = false
        ffwdLogoTapCount = 0
        testEventStartDay = ""
        adSlotOverride = .automatic
        simulatedTimeMinutes = -1
        useSimulatedDate = false
        syncCurrentDate()
        locationController.clearTestRegion()
        locationController.requestLocationAccess()
        syncMapPosition()
        refreshMorningOutsideBannerVariant()
        evaluateMissedDayNotice()
    }

    func syncCurrentDate() {
        currentDate = Date()
    }

    func syncMapPosition() {
        mapPosition = .region(locationController.activeMapRegion)
    }
}
