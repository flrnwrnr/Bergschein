//
//  AppModels.swift
//  Bergschein
//

import CoreLocation
import Foundation
import UIKit

enum BadgeCategory: String, CaseIterable, Identifiable {
    case netterAnfang = "Netter Anfang"
    case solideLeistung = "Solide Leistung"
    case profi = "Profi"

    var id: String { rawValue }
}

struct OnboardingPage {
    let icon: String
    let title: String
    let text: String
    var requiresLocationAuthorization = false
    var showsRafflePrizes = false

    var usesEmojiIcon: Bool {
        !icon.allSatisfy(\.isASCII)
    }
}

struct BadgeDefinition: Identifiable {
    let id: String
    let name: String
    let shortLabel: String
    let month: Int
    let day: Int
    let category: BadgeCategory
    let subtitle: String?
    let imageName: String?
    let overlayMessage: String
    let sponsorLabel: String?
    let sponsorLogoName: String?
    let sponsorURL: URL?

    var overlayTitle: String {
        "Tag \(displayDayIndex)"
    }

    var displayDayIndex: Int {
        Self.all.firstIndex(where: { $0.id == id }).map { $0 + 1 } ?? 0
    }

    static let all: [BadgeDefinition] = [
        BadgeDefinition(id: "05-21", name: "21.05.", shortLabel: "21.05.", month: 5, day: 21, category: .netterAnfang, subtitle: nil, imageName: "badge1", overlayMessage: "Der Auftakt ist geschafft. Dein Bergschein hat seinen ersten Stempel.", sponsorLabel: nil, sponsorLogoName: nil, sponsorURL: nil),
        BadgeDefinition(id: "05-22", name: "22.05.", shortLabel: "22.05.", month: 5, day: 22, category: .netterAnfang, subtitle: nil, imageName: "badge2", overlayMessage: "Tag zwei sitzt. So sammelt sich der Bergschein Schritt für Schritt.", sponsorLabel: nil, sponsorLogoName: nil, sponsorURL: nil),
        BadgeDefinition(id: "05-23", name: "23.05.", shortLabel: "23.05.", month: 5, day: 23, category: .netterAnfang, subtitle: nil, imageName: "badge3", overlayMessage: "Drei Tage in Folge sehen schon nach echter Routine aus.", sponsorLabel: nil, sponsorLogoName: nil, sponsorURL: nil),
        BadgeDefinition(id: "05-24", name: "24.05.", shortLabel: "24.05.", month: 5, day: 24, category: .solideLeistung, subtitle: nil, imageName: "badge4", overlayMessage: "Starker Lauf. Du bist jetzt sichtbar in der soliden Phase angekommen.", sponsorLabel: nil, sponsorLogoName: nil, sponsorURL: nil),
        BadgeDefinition(id: "05-25", name: "25.05.", shortLabel: "25.05.", month: 5, day: 25, category: .solideLeistung, subtitle: nil, imageName: "badge5", overlayMessage: "Halbherzig ist das nicht mehr. Dein Bergschein wächst konstant weiter.", sponsorLabel: nil, sponsorLogoName: nil, sponsorURL: nil),
        BadgeDefinition(id: "05-26", name: "26.05.", shortLabel: "26.05.", month: 5, day: 26, category: .solideLeistung, subtitle: nil, imageName: "badge6", overlayMessage: "Wieder abgestempelt. Genau so wird aus einer Idee ein echter Lauf.", sponsorLabel: nil, sponsorLogoName: nil, sponsorURL: nil),
        BadgeDefinition(id: "05-27", name: "27.05.", shortLabel: "27.05.", month: 5, day: 27, category: .solideLeistung, subtitle: nil, imageName: "badge7", overlayMessage: "Sieben Tage machen Eindruck. Das ist längst mehr als nur ein Versuch.", sponsorLabel: nil, sponsorLogoName: nil, sponsorURL: nil),
        BadgeDefinition(id: "05-28", name: "28.05.", shortLabel: "28.05.", month: 5, day: 28, category: .profi, subtitle: nil, imageName: "badge8", overlayMessage: "Ab jetzt wird es ernst. Du bist klar auf Profi-Kurs unterwegs.", sponsorLabel: nil, sponsorLogoName: nil, sponsorURL: nil),
        BadgeDefinition(id: "05-29", name: "29.05.", shortLabel: "29.05.", month: 5, day: 29, category: .profi, subtitle: nil, imageName: "badge9", overlayMessage: "Noch ein Profi-Tag. Der große Bergschein rückt spürbar näher.", sponsorLabel: nil, sponsorLogoName: nil, sponsorURL: nil),
        BadgeDefinition(id: "05-30", name: "30.05.", shortLabel: "30.05.", month: 5, day: 30, category: .profi, subtitle: nil, imageName: "badge10", overlayMessage: "Die letzten Meter laufen. Dein Bergschein ist fast komplett.", sponsorLabel: nil, sponsorLogoName: nil, sponsorURL: nil),
        BadgeDefinition(id: "05-31", name: "31.05.", shortLabel: "31.05.", month: 5, day: 31, category: .profi, subtitle: nil, imageName: "badge11", overlayMessage: "Vorletzter Stempel. Viel näher kannst du dem Finale kaum noch kommen.", sponsorLabel: nil, sponsorLogoName: nil, sponsorURL: nil),
        BadgeDefinition(id: "06-01", name: "01.06.", shortLabel: "01.06.", month: 6, day: 1, category: .profi, subtitle: "Großer Bergschein", imageName: "badge12", overlayMessage: "Geschafft. Der große Bergschein gehört jetzt dir.", sponsorLabel: "Gesponsert vom", sponsorLogoName: "logo_erich", sponsorURL: URL(string: "https://www.erich-keller.net"))
    ]
}

struct BadgeOverlayPresentation {
    let badge: BadgeDefinition
    let title: String
    let buttonTitle: String
    let switchesToBadgeTab: Bool
    let subtitleOverride: String?
    let messageOverride: String?
}

struct BadgeShareSheetItem: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct MissedDayAlertPresentation {
    let missedBadge: BadgeDefinition
}

struct ChallengeOverlayPresentation {
    let challenge: DailyChallenge
}

struct ChallengeReward: Identifiable {
    let id: String
    let icon: String
    let imageName: String?
    let title: String
    let subtitle: String
    let details: String
    let infoURL: URL?
    let redemptionHint: String

    static let tbBasketballDrink = ChallengeReward(
        id: "tb-basketball-drink",
        icon: "",
        imageName: "werbung_tb",
        title: "Freigetränk freigeschaltet",
        subtitle: "TB Erlangen Basketball",
        details: "Du erhältst ein Freigetränk bei einem Damen 1 oder Herren 1 Spiel deiner Wahl.",
        infoURL: URL(string: "https://www.instagram.com/tberlangenbasketball/"),
        redemptionHint: "Hinweis: Der Einlösen-Button darf nur einmal von der Getränkeausgabe verwendet werden."
    )

    static let zirkelFreeEntry = ChallengeReward(
        id: "zirkel-free-entry",
        icon: "",
        imageName: "werbung_zirkel",
        title: "Kostenloser Eintritt freigeschaltet",
        subtitle: "Der Zirkel",
        details: "Du erhältst einen kostenlosen Eintritt in den Zirkel in den Monaten Juni oder Juli 2026.",
        infoURL: URL(string: "https://zirkel-club.de"),
        redemptionHint: "Hinweis: Der Einlösen-Button kann nur einmal und nur im Juni/Juli 2026 verwendet werden."
    )

    static let bibOfferCode = ChallengeReward(
        id: "bib-offer-code",
        icon: "",
        imageName: "studybro",
        title: "Promo Code freigeschaltet",
        subtitle: "Study Bro",
        details: "Du erhältst über den Promo Code ein kostenloses Jahresabo für die App Study Bro.",
        infoURL: nil,
        redemptionHint: "Hinweis: Der Einlösen-Button öffnet den Promo-Code-Link nur einmal und kann danach nicht erneut verwendet werden."
    )
}

struct ChallengeRewardOverlayPresentation {
    let reward: ChallengeReward
}

struct DailyChallenge: Identifiable {
    let id: String
    let icon: String
    let title: String
    let text: String
    let locationName: String
    let month: Int
    let day: Int
    let year: Int
    let startHour: Int?
    let startMinute: Int?
    let endHour: Int?
    let endMinute: Int?
    let centerCoordinate: CLLocationCoordinate2D?
    let radius: CLLocationDistance?
    let requiresLocationCheckIn: Bool

    var date: Date {
        let components = DateComponents(year: year, month: month, day: day)
        return Calendar.current.date(from: components) ?? .now
    }

    var startDate: Date? {
        guard let startHour, let startMinute else {
            return nil
        }

        return Calendar.current.date(
            bySettingHour: startHour,
            minute: startMinute,
            second: 0,
            of: date
        )
    }

    var endDate: Date? {
        guard let endHour, let endMinute else {
            return nil
        }

        let sameDayEndDate = Calendar.current.date(
            bySettingHour: endHour,
            minute: endMinute,
            second: 0,
            of: date
        )

        guard let sameDayEndDate else {
            return nil
        }

        if spansMidnight {
            return Calendar.current.date(byAdding: .day, value: 1, to: sameDayEndDate)
        }

        return sameDayEndDate
    }

    var spansMidnight: Bool {
        guard let startHour, let startMinute, let endHour, let endMinute else {
            return false
        }

        return (endHour, endMinute) < (startHour, startMinute)
    }

    var dateLabel: String {
        String(format: "%02d.%02d.%04d", day, month, year)
    }

    var timeWindowLabel: String {
        guard let startHour, let startMinute, let endHour, let endMinute else {
            return "ganztägig"
        }

        return String(format: "%02d:%02d–%02d:%02d Uhr", startHour, startMinute, endHour, endMinute)
    }

    var completionTitle: String {
        "Challenge abgehakt!"
    }

    var completionMessage: String {
        switch id {
        case "2026-05-21":
            return "Du warst pünktlich beim Anstich an der T-Kreuzung dabei. Starker Auftakt."
        case "2026-05-22":
            return "Zirkel bei Nacht sitzt. Die zweite Challenge ist dir sicher."
        case "2026-05-23":
            return "Der Abstecher zum BMS ist geschafft. Challenge erfolgreich abgehakt."
        default:
            return "Diese Tageschallenge hast du erfolgreich abgehakt."
        }
    }

    static let all: [DailyChallenge] = [
        DailyChallenge(id: "2026-05-21", icon: "🥳", title: "Anstich an der T-Kreuzung", text: "Checke zwischen 16:00 und 18:00 Uhr am sogenannten T zum Anstich ein.", locationName: "T-Kreuzung", month: 5, day: 21, year: 2026, startHour: 16, startMinute: 0, endHour: 18, endMinute: 0, centerCoordinate: CLLocationCoordinate2D(latitude: 49.60756, longitude: 11.00512), radius: 50, requiresLocationCheckIn: true),
        DailyChallenge(id: "2026-05-22", icon: "🪩", title: "Afterberg im Zirkel", text: "Checke am 22.05. zwischen 21:00 und 23:59 Uhr im Zirkel ein und feier im Klassiker.", locationName: "Zirkel", month: 5, day: 22, year: 2026, startHour: 20, startMinute: 0, endHour: 23, endMinute: 59, centerCoordinate: CLLocationCoordinate2D(latitude: 49.60240, longitude: 11.00360), radius: 100, requiresLocationCheckIn: true),
        DailyChallenge(id: "2026-05-23", icon: "🏀", title: "Ballen am BMS", text: "Mach am 23.05. einen Abstecher zum BMS, werfe dort ein paar Körbe, und hake die Challenge direkt vor Ort ab.", locationName: "BMS", month: 5, day: 23, year: 2026, startHour: 10, startMinute: 0, endHour: 18, endMinute: 0, centerCoordinate: CLLocationCoordinate2D(latitude: 49.60266, longitude: 11.02082), radius: 200, requiresLocationCheckIn: true),
        DailyChallenge(id: "2026-05-24", icon: "🥨", title: "Frühschoppen am Erich Keller", text: "Mach am 24.05. einen Abstecher zum Frühschoppen am Erich Keller und hake die Challenge direkt vor Ort ab.", locationName: "Erich Keller", month: 5, day: 24, year: 2026, startHour: 10, startMinute: 0, endHour: 20, endMinute: 0, centerCoordinate: CLLocationCoordinate2D(latitude: 49.60771, longitude: 11.00417), radius: 70, requiresLocationCheckIn: true),
        DailyChallenge(id: "2026-05-25", icon: "🎡", title: "Pflichtfahrt im Riesenrad", text: "Dreh am 25.05. zwischen 10:00 und 23:00 Uhr die Pflichtfahrt im Riesenrad, die zu jedem Berg einfach dazugehört, und hake die Challenge direkt vor Ort ab.", locationName: "Riesenrad", month: 5, day: 25, year: 2026, startHour: 10, startMinute: 0, endHour: 23, endMinute: 0, centerCoordinate: CLLocationCoordinate2D(latitude: 49.60714, longitude: 11.00681), radius: 100, requiresLocationCheckIn: true),
        DailyChallenge(id: "2026-05-26", icon: "📚", title: "Besuch in der Bib", text: "Geh am 26.05. mal wieder in die Unibib, damit du das Lernen nicht ganz vergisst 😉", locationName: "Unibib", month: 5, day: 26, year: 2026, startHour: 10, startMinute: 0, endHour: 20, endMinute: 0, centerCoordinate: CLLocationCoordinate2D(latitude: 49.59661, longitude: 11.00713), radius: 120, requiresLocationCheckIn: true),
        DailyChallenge(id: "2026-05-27", icon: "🌿", title: "Erholsamer Besuch im Aromagarten", text: "Mach am 27.05. einen erholsamen Abstecher in den Aromagarten und hake die Challenge direkt vor Ort ab.", locationName: "Aromagarten", month: 5, day: 27, year: 2026, startHour: 10, startMinute: 0, endHour: 20, endMinute: 0, centerCoordinate: CLLocationCoordinate2D(latitude: 49.60268, longitude: 11.01638), radius: 120, requiresLocationCheckIn: true),
        DailyChallenge(id: "2026-05-28", icon: "🏁", title: "Auto-Scooter mit den Kids", text: "Fahr am 28.05. zwischen 10:00 und 23:00 Uhr eine Runde Auto-Scooter mit den Kids und hake die Challenge direkt vor Ort ab.", locationName: "Auto-Scooter", month: 5, day: 28, year: 2026, startHour: 10, startMinute: 0, endHour: 23, endMinute: 0, centerCoordinate: CLLocationCoordinate2D(latitude: 49.60709, longitude: 11.00758), radius: 100, requiresLocationCheckIn: true),
        DailyChallenge(id: "2026-05-29", icon: "🌳", title: "Besuch im Schlossgarten", text: "Mach am 29.05. einen Besuch in Erlangens Highlight, dem Schlossgarten, und hake die Challenge direkt vor Ort ab.", locationName: "Schlossgarten", month: 5, day: 29, year: 2026, startHour: 10, startMinute: 0, endHour: 20, endMinute: 0, centerCoordinate: CLLocationCoordinate2D(latitude: 49.59801, longitude: 11.00525), radius: 120, requiresLocationCheckIn: true),
        DailyChallenge(id: "2026-05-30", icon: "⛪️", title: "Check-in am Kirchenplatz", text: "Hol dir am 30.05. am Kirchenplatz kurz den dringend notwendigen Segen ab und hake die Challenge direkt vor Ort ab.", locationName: "Kirchenplatz", month: 5, day: 30, year: 2026, startHour: 10, startMinute: 0, endHour: 20, endMinute: 0, centerCoordinate: CLLocationCoordinate2D(latitude: 49.60128, longitude: 11.00814), radius: 100, requiresLocationCheckIn: true),
        DailyChallenge(id: "2026-05-31", icon: "🌳", title: "Treffen am Bohlenplatz", text: "Mach am 31.05. einen Abstecher zum Bohlenplatz im Herzen Erlangens und hake die Challenge direkt vor Ort ab.", locationName: "Bohlenplatz", month: 5, day: 31, year: 2026, startHour: 12, startMinute: 0, endHour: 20, endMinute: 0, centerCoordinate: CLLocationCoordinate2D(latitude: 49.59662, longitude: 11.01111), radius: 100, requiresLocationCheckIn: true),
        DailyChallenge(id: "2026-06-01", icon: "👋", title: "Ein letzter Besuch", text: "Komm am 01.06. noch ein letztes Mal hoch und hake die finale Challenge direkt vor Ort ab.", locationName: "T-Kreuzung", month: 6, day: 1, year: 2026, startHour: 10, startMinute: 0, endHour: 20, endMinute: 0, centerCoordinate: CLLocationCoordinate2D(latitude: 49.60756, longitude: 11.00512), radius: 50, requiresLocationCheckIn: true)
    ]
}

struct AfterBergLocation: Identifiable {
    enum Kind {
        case bar
        case club
        case other
    }

    let id: String
    let name: String
    let category: String
    let address: String
    let description: String
    let website: URL
    let icon: String
    let kind: Kind

    var marker: String {
        switch kind {
        case .bar:
            return "🍻"
        case .club:
            return "🪩"
        case .other:
            return "🍻"
        }
    }
}

struct AdBanner {
    let imageName: String?
    let title: String
    let text: String
    let url: URL

    static let ffwd = AdBanner(
        imageName: "werbung_ffwd",
        title: "FFWD Ventures",
        text: "App oder Webseite gefällig? Wir bauen alles schnell und unkompliziert!",
        url: URL(string: "https://ffwdventures.de/index-de.html")!
    )

    static let ching = AdBanner(
        imageName: "werbung_ching",
        title: "CHING Coatings",
        text: "Wir schreiben Tradition seit 1927. Schreibst Du mit? Bewirb Dich jetzt!",
        url: URL(string: "https://www.ching-coatings.com/arbeiten-bei-ching/")!
    )

    static let tb = AdBanner(
        imageName: "werbung_tb",
        title: "TB Basketball",
        text: "Bock auf Regionalligabasketball? Dann komm zum besten Basketballverein der Stadt!",
        url: URL(string: "https://www.instagram.com/tberlangenbasketball/")!
    )

    static let erich = AdBanner(
        imageName: "werbung_erich",
        title: "Erich Keller",
        text: "Auf der Suche nach dem Keller mit der besten Stimmung? Hier entlang!",
        url: URL(string: "https://www.erich-keller.net")!
    )

    static let zirkel = AdBanner(
        imageName: "werbung_zirkel",
        title: "Zirkel",
        text: "Vom Bergkeller ab in deinen Lieblingskeller! Worauf wartest du?",
        url: URL(string: "https://zirkel-club.de")!
    )
}
