//
//  AppDateHelpers.swift
//  Bergschein
//

import Foundation

enum BergscheinDateHelper {
    static let eventCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }()

    // Preview only: this date must not determine the existing stamp season.
    static let nextOpeningDate = date(
        year: 2027, month: 5, day: 13, hour: 17, minute: 0,
        calendar: eventCalendar
    )!

    static func mergedDate(day: Date, timeSource: Date, calendar: Calendar = .current) -> Date {
        let targetDay = calendar.dateComponents([.year, .month, .day], from: day)
        let time = calendar.dateComponents([.hour, .minute, .second], from: timeSource)
        var merged = DateComponents()
        merged.year = targetDay.year
        merged.month = targetDay.month
        merged.day = targetDay.day
        merged.hour = time.hour
        merged.minute = time.minute
        merged.second = time.second
        return calendar.date(from: merged) ?? day
    }

    static func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        calendar: Calendar = .current
    ) -> Date? {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = 0
        return calendar.date(from: components)
    }

    static func countdownText(
        from currentDate: Date,
        to targetDate: Date,
        calendar: Calendar = .current
    ) -> String {
        let components = calendar.dateComponents([.day, .hour, .minute, .second], from: currentDate, to: targetDate)
        let days = max(components.day ?? 0, 0)
        let hours = max(components.hour ?? 0, 0)
        let minutes = max(components.minute ?? 0, 0)
        let seconds = max(components.second ?? 0, 0)

        var parts: [String] = []
        if days > 0 {
            parts.append("\(days) \(days == 1 ? "Tag" : "Tage")")
        }
        if hours > 0 || !parts.isEmpty {
            parts.append("\(hours) Std.")
        }
        if minutes > 0 || !parts.isEmpty {
            parts.append("\(minutes) Min.")
        }
        parts.append("\(seconds)s")

        if parts.count > 2 {
            let firstLine = parts.prefix(2).joined(separator: " ")
            let secondLine = parts.dropFirst(2).joined(separator: " ")
            return "\(firstLine)\n\(secondLine)"
        }

        return parts.joined(separator: " ")
    }
}
