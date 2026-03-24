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

    func simulatedDate(for targetDate: Date, usingTimeFrom timeSource: Date) -> Date {
        BergscheinDateHelper.mergedDate(day: targetDate, timeSource: timeSource)
    }

    func goToNextDay() {
        ensureTestEventStartDay()

        if !useSimulatedDate {
            useSimulatedDate = true
            currentDate = defaultEventStartDate.map { simulatedDate(for: $0, usingTimeFrom: Date()) } ?? currentDate
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
        testEventStartDay = ""
        withAnimation(overlayDismissAnimation) {
            activeBadgeOverlay = nil
            activeChallengeOverlay = nil
            activeMissedDayAlert = nil
        }
        dismissedMissedBadgeIdentifier = ""
        adSlotOverride = .automatic
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
