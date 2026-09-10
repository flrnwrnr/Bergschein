import MapKit
import SwiftUI

extension ContentView {
    var isTestModeActive: Bool {
        useSimulatedDate || locationController.isUsingTestRegion || adSlotOverride != .automatic
    }

    var formattedCurrentDate: String {
        let displayDate = useSimulatedDate ? currentDate : Date()
        return displayDate.formatted(
            Date.FormatStyle(
                date: .abbreviated, time: .shortened,
                timeZone: useSimulatedDate ? BergscheinDateHelper.eventCalendar.timeZone : .current
            )
        )
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
        let calendar = BergscheinDateHelper.eventCalendar
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

        let calendar = BergscheinDateHelper.eventCalendar
        let hour = simulatedTimeMinutes / 60
        let minute = simulatedTimeMinutes % 60
        var components = calendar.dateComponents([.year, .month, .day], from: liveDate)
        components.hour = hour
        components.minute = minute
        components.second = 0
        return calendar.date(from: components) ?? liveDate
    }

    func setSimulatedTime(from pickerDate: Date) {
        let components = BergscheinDateHelper.eventCalendar.dateComponents([.hour, .minute], from: pickerDate)
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
        BergscheinDateHelper.mergedDate(day: targetDate, timeSource: timeSource, calendar: BergscheinDateHelper.eventCalendar)
    }

    func goToNextDay() {
        ensureTestEventStartDay()

        if !useSimulatedDate {
            useSimulatedDate = true
            if !hasSimulatedTimeOverride {
                simulatedTimeMinutes = 17 * 60
            }
            currentDate = simulatedDate(for: testEventStartDate, usingTimeFrom: simulatedTimeSource(from: Date()))
            selectedBadgeSeason = activeBadgeSeason
            evaluateMissedDayNotice()
            return
        }

        useSimulatedDate = true
        currentDate = BergscheinDateHelper.eventCalendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        evaluateMissedDayNotice()
    }

    func resetProgress() {
        seasonProgressStore.resetProgress(in: activeBadgeSeason.id)
        withAnimation(overlayDismissAnimation) {
            activeBadgeOverlay = nil
            activeChallengeRewardOverlay = nil
            activeChallengeOverlay = nil
            activeMissedDayAlert = nil
        }
        dismissedMissedBadgeIdentifier = ""
        dismissedMissedNoticeBadgeIdentifier = ""
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
