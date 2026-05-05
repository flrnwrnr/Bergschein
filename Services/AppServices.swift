//
//  AppServices.swift
//  Bergschein
//

import Combine
import CoreLocation
import Foundation
import MapKit
import StoreKit
import SwiftUI

enum AnalyticsEventType: String, Codable {
    case badgeClaimed = "badge_claimed"
    case challengeCompleted = "challenge_completed"
}

struct RaffleEntryRequest {
    let installID: String
    let email: String
    let name: String?
    let termsVersion: String
    let contactConsent: Bool
    let ageConfirmed: Bool
    let badgeCountAtConsent: Int
    let challengeCountAtConsent: Int
    let isPerfectSoFar: Bool
}

struct CommunityDistributionEntry: Decodable, Identifiable {
    let checkins: Int
    let users: Int
    let percentage: Double

    var id: Int { checkins }
}

struct CommunityStats: Decodable {
    let generatedAt: String
    let basis: String
    let totalCollectors: Int
    let averageCheckins: Double
    let maxCheckins: Int
    let distribution: [CommunityDistributionEntry]
}

actor AnalyticsService {
    private enum Config {
        static let endpointInfoKey = "ANALYTICS_ENDPOINT"
        static let appTokenInfoKey = "ANALYTICS_APP_TOKEN"
        static let raffleEndpointInfoKey = "RAFFLE_ENDPOINT"
        static let communityStatsEndpointInfoKey = "COMMUNITY_STATS_ENDPOINT"
        static let fallbackEndpoint = "https://api.derbergschein.de/track.php"
        static let fallbackRaffleEndpoint = "https://api.derbergschein.de/raffle.php"
        static let fallbackCommunityStatsEndpoint = "https://api.derbergschein.de/community.php"
        static let pendingQueueStorageKey = "analyticsPendingEventQueueV1"
        static let requestTimeout: TimeInterval = 8
        static let maxQueuedEvents = 200

        static var endpoint: String {
            guard let configuredEndpoint = Bundle.main.object(forInfoDictionaryKey: endpointInfoKey) as? String,
                  !configuredEndpoint.isEmpty else {
                return fallbackEndpoint
            }
            return configuredEndpoint
        }

        static var appToken: String {
            (Bundle.main.object(forInfoDictionaryKey: appTokenInfoKey) as? String) ?? ""
        }

        static var raffleEndpoint: String {
            guard let configuredEndpoint = Bundle.main.object(forInfoDictionaryKey: raffleEndpointInfoKey) as? String,
                  !configuredEndpoint.isEmpty else {
                return fallbackRaffleEndpoint
            }
            return configuredEndpoint
        }

        static var communityStatsEndpoint: String {
            guard let configuredEndpoint = Bundle.main.object(forInfoDictionaryKey: communityStatsEndpointInfoKey) as? String,
                  !configuredEndpoint.isEmpty else {
                return fallbackCommunityStatsEndpoint
            }
            return configuredEndpoint
        }
    }

    private struct EventPayload: Codable {
        let installID: String
        let eventType: String
        let eventTime: String
        let badgeCountAfterEvent: Int
        let isPerfectSoFar: Bool
        let challengeCountAfterEvent: Int

        enum CodingKeys: String, CodingKey {
            case installID = "install_id"
            case eventType = "event_type"
            case eventTime = "event_time"
            case badgeCountAfterEvent = "badge_count_after_event"
            case isPerfectSoFar = "is_perfect_so_far"
            case challengeCountAfterEvent = "challenge_count_after_event"
        }
    }

    private struct RaffleEntryPayload: Codable {
        let installID: String
        let email: String
        let name: String?
        let termsVersion: String
        let contactConsent: Bool
        let ageConfirmed: Bool
        let badgeCountAtConsent: Int
        let challengeCountAtConsent: Int
        let isPerfectSoFar: Bool

        enum CodingKeys: String, CodingKey {
            case installID = "install_id"
            case email
            case name
            case termsVersion = "terms_version"
            case contactConsent = "contact_consent"
            case ageConfirmed = "age_confirmed"
            case badgeCountAtConsent = "badge_count_at_consent"
            case challengeCountAtConsent = "challenge_count_at_consent"
            case isPerfectSoFar = "is_perfect_so_far"
        }
    }

    private struct CommunityStatsResponse: Decodable {
        let ok: Bool
        let generatedAt: String
        let basis: String
        let totalCollectors: Int
        let averageCheckins: Double
        let maxCheckins: Int
        let distribution: [CommunityDistributionEntry]

        enum CodingKeys: String, CodingKey {
            case ok
            case generatedAt = "generated_at"
            case basis
            case totalCollectors = "total_collectors"
            case averageCheckins = "average_checkins"
            case maxCheckins = "max_checkins"
            case distribution
        }
    }

    private let iso8601Formatter = ISO8601DateFormatter()
    private let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = Config.requestTimeout
        configuration.timeoutIntervalForResource = Config.requestTimeout + 4
        return URLSession(configuration: configuration)
    }()

    func track(
        eventType: AnalyticsEventType,
        installID: String,
        eventDate: Date,
        badgeCountAfterEvent: Int,
        isPerfectSoFar: Bool,
        challengeCountAfterEvent: Int
    ) async {
        guard let url = URL(string: Config.endpoint),
              !Config.appToken.isEmpty else {
            return
        }

        let payload = EventPayload(
            installID: installID,
            eventType: eventType.rawValue,
            eventTime: iso8601Formatter.string(from: eventDate),
            badgeCountAfterEvent: badgeCountAfterEvent,
            isPerfectSoFar: isPerfectSoFar,
            challengeCountAfterEvent: challengeCountAfterEvent
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = Config.requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.appToken, forHTTPHeaderField: "X-App-Token")

        do {
            request.httpBody = try JSONEncoder().encode(payload)
            if try await send(request: request) {
                await flushPendingEvents()
            } else {
                enqueuePendingEvent(payload)
            }
        } catch {
            enqueuePendingEvent(payload)
        }
    }

    func flushPendingEvents() async {
        guard let url = URL(string: Config.endpoint),
              !Config.appToken.isEmpty else {
            return
        }

        var queue = loadPendingEvents()
        guard !queue.isEmpty else {
            return
        }

        var remainingQueue: [EventPayload] = []

        while !queue.isEmpty {
            let payload = queue.removeFirst()
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = Config.requestTimeout
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(Config.appToken, forHTTPHeaderField: "X-App-Token")

            do {
                request.httpBody = try JSONEncoder().encode(payload)
                let sent = try await send(request: request)
                if !sent {
                    remainingQueue.append(payload)
                    remainingQueue.append(contentsOf: queue)
                    break
                }
            } catch {
                remainingQueue.append(payload)
                remainingQueue.append(contentsOf: queue)
                break
            }
        }

        savePendingEvents(remainingQueue)
    }

    func submitRaffleEntry(_ requestModel: RaffleEntryRequest) async -> Bool {
        guard let url = URL(string: Config.raffleEndpoint),
              !Config.appToken.isEmpty else {
            return false
        }

        let payload = RaffleEntryPayload(
            installID: requestModel.installID,
            email: requestModel.email,
            name: requestModel.name,
            termsVersion: requestModel.termsVersion,
            contactConsent: requestModel.contactConsent,
            ageConfirmed: requestModel.ageConfirmed,
            badgeCountAtConsent: requestModel.badgeCountAtConsent,
            challengeCountAtConsent: requestModel.challengeCountAtConsent,
            isPerfectSoFar: requestModel.isPerfectSoFar
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = Config.requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.appToken, forHTTPHeaderField: "X-App-Token")

        do {
            request.httpBody = try JSONEncoder().encode(payload)
            return try await send(request: request)
        } catch {
            return false
        }
    }

    func fetchCommunityStats() async throws -> CommunityStats? {
        guard let url = URL(string: Config.communityStatsEndpoint),
              !Config.appToken.isEmpty else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = Config.requestTimeout
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue(Config.appToken, forHTTPHeaderField: "X-App-Token")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            return nil
        }

        let decoded = try JSONDecoder().decode(CommunityStatsResponse.self, from: data)
        guard decoded.ok else {
            return nil
        }

        return CommunityStats(
            generatedAt: decoded.generatedAt,
            basis: decoded.basis,
            totalCollectors: decoded.totalCollectors,
            averageCheckins: decoded.averageCheckins,
            maxCheckins: decoded.maxCheckins,
            distribution: decoded.distribution
        )
    }

    private func send(request: URLRequest) async throws -> Bool {
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            return false
        }

        return (200...299).contains(httpResponse.statusCode)
    }

    private func enqueuePendingEvent(_ payload: EventPayload) {
        var queue = loadPendingEvents()
        queue.append(payload)

        if queue.count > Config.maxQueuedEvents {
            queue = Array(queue.suffix(Config.maxQueuedEvents))
        }

        savePendingEvents(queue)
    }

    private func loadPendingEvents() -> [EventPayload] {
        guard let data = UserDefaults.standard.data(forKey: Config.pendingQueueStorageKey) else {
            return []
        }

        return (try? JSONDecoder().decode([EventPayload].self, from: data)) ?? []
    }

    private func savePendingEvents(_ queue: [EventPayload]) {
        if queue.isEmpty {
            UserDefaults.standard.removeObject(forKey: Config.pendingQueueStorageKey)
            return
        }

        if let data = try? JSONEncoder().encode(queue) {
            UserDefaults.standard.set(data, forKey: Config.pendingQueueStorageKey)
        }
    }
}

@MainActor
final class TipJarStore: ObservableObject {
    @Published var products: [Product] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var purchaseInProgressProductID: String?

    private let productIDs = [
        "kleines_trinkgeld",
        "mittleres_trinkgeld",
        "grosses_trinkgeld"
    ]

    func loadProducts() async {
        guard products.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        do {
            let storeProducts = try await Product.products(for: productIDs)
            products = productIDs.compactMap { productID in
                storeProducts.first(where: { $0.id == productID })
            }
        } catch {
            errorMessage = "Die Trinkgeldoptionen konnten gerade nicht geladen werden."
        }

        isLoading = false
    }

    func purchase(_ product: Product) async {
        purchaseInProgressProductID = product.id
        errorMessage = nil
        successMessage = nil

        defer {
            purchaseInProgressProductID = nil
        }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                successMessage = "Vielen Dank für dein Trinkgeld!"
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = "Der Kauf konnte nicht abgeschlossen werden."
        }
    }

    func emoji(for productID: String) -> String {
        switch productID {
        case "kleines_trinkgeld":
            return "🥛"
        case "mittleres_trinkgeld":
            return "🍺"
        case "grosses_trinkgeld":
            return "🍻"
        default:
            return "❤️"
        }
    }

    func title(for product: Product) -> String {
        switch product.id {
        case "kleines_trinkgeld":
            return "Kleines Trinkgeld"
        case "mittleres_trinkgeld":
            return "Großes Trinkgeld"
        case "grosses_trinkgeld":
            return "Noch größeres Trinkgeld"
        default:
            return product.displayName
        }
    }

    func subtitle(for product: Product) -> String {
        switch product.id {
        case "kleines_trinkgeld":
            return "Ein kleines Danke und Support."
        case "mittleres_trinkgeld":
            return "Eine Halbe auf deinen Nacken."
        case "grosses_trinkgeld":
            return "Ein großes Danke und eine Runde für die Weiterentwicklung."
        default:
            return product.description
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    private enum StoreError: Error {
        case failedVerification
    }
}

@MainActor
final class LocationController: NSObject, ObservableObject, CLLocationManagerDelegate {
    enum TestPolygon {
        case original
        case alternate
        case compact
        case southern
    }

    static let originalRegionPolygon: [CLLocationCoordinate2D] = [
        CLLocationCoordinate2D(latitude: 49.59639, longitude: 11.01202),
        CLLocationCoordinate2D(latitude: 49.59682, longitude: 11.01634),
        CLLocationCoordinate2D(latitude: 49.59882, longitude: 11.01578),
        CLLocationCoordinate2D(latitude: 49.59834, longitude: 11.01032),
        CLLocationCoordinate2D(latitude: 49.59579, longitude: 11.01167)
    ]

    static let alternateRegionPolygon: [CLLocationCoordinate2D] = [
        CLLocationCoordinate2D(latitude: 49.60788, longitude: 11.00231),
        CLLocationCoordinate2D(latitude: 49.60821, longitude: 11.00240),
        CLLocationCoordinate2D(latitude: 49.60832, longitude: 11.00411),
        CLLocationCoordinate2D(latitude: 49.60814, longitude: 11.00639),
        CLLocationCoordinate2D(latitude: 49.60785, longitude: 11.00689),
        CLLocationCoordinate2D(latitude: 49.60780, longitude: 11.00844),
        CLLocationCoordinate2D(latitude: 49.60733, longitude: 11.00923),
        CLLocationCoordinate2D(latitude: 49.60736, longitude: 11.01156),
        CLLocationCoordinate2D(latitude: 49.60685, longitude: 11.01303),
        CLLocationCoordinate2D(latitude: 49.60672, longitude: 11.01118),
        CLLocationCoordinate2D(latitude: 49.60653, longitude: 11.00942),
        CLLocationCoordinate2D(latitude: 49.60683, longitude: 11.00862),
        CLLocationCoordinate2D(latitude: 49.60695, longitude: 11.00665),
        CLLocationCoordinate2D(latitude: 49.60656, longitude: 11.00652),
        CLLocationCoordinate2D(latitude: 49.60657, longitude: 11.00608),
        CLLocationCoordinate2D(latitude: 49.60644, longitude: 11.00604),
        CLLocationCoordinate2D(latitude: 49.60642, longitude: 11.00532),
        CLLocationCoordinate2D(latitude: 49.60573, longitude: 11.00539),
        CLLocationCoordinate2D(latitude: 49.60573, longitude: 11.00508),
        CLLocationCoordinate2D(latitude: 49.60648, longitude: 11.00510),
        CLLocationCoordinate2D(latitude: 49.60712, longitude: 11.00467),
        CLLocationCoordinate2D(latitude: 49.60754, longitude: 11.00346),
        CLLocationCoordinate2D(latitude: 49.60779, longitude: 11.00289),
        CLLocationCoordinate2D(latitude: 49.60782, longitude: 11.00217)
    ]

    static let compactRegionPolygon: [CLLocationCoordinate2D] = [
        CLLocationCoordinate2D(latitude: 49.59600, longitude: 11.00298),
        CLLocationCoordinate2D(latitude: 49.59546, longitude: 11.00313),
        CLLocationCoordinate2D(latitude: 49.59559, longitude: 11.00364),
        CLLocationCoordinate2D(latitude: 49.59641, longitude: 11.00328)
    ]

    static let southernRegionPolygon: [CLLocationCoordinate2D] = [
        CLLocationCoordinate2D(latitude: 49.58432, longitude: 11.00301),
        CLLocationCoordinate2D(latitude: 49.58441, longitude: 11.00569),
        CLLocationCoordinate2D(latitude: 49.58309, longitude: 11.00591),
        CLLocationCoordinate2D(latitude: 49.58314, longitude: 11.00316)
    ]

    static func mapRegion(for polygonCoordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        let polygon = MKPolygon(coordinates: polygonCoordinates, count: polygonCoordinates.count)
        let boundingRect = polygon.boundingMapRect
        let region = MKCoordinateRegion(boundingRect)

        return MKCoordinateRegion(
            center: region.center,
            span: MKCoordinateSpan(
                latitudeDelta: region.span.latitudeDelta * 1.4,
                longitudeDelta: region.span.longitudeDelta * 1.4
            )
        )
    }

    @Published private(set) var isInAllowedRegion = false
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var statusText = "Standort wird geprüft."
    @Published private(set) var isUsingTestRegion = false
    @Published private(set) var activeTestPolygon: TestPolygon = .alternate
    @Published private(set) var distanceToRegionText: String?
    @Published private(set) var distanceToRegionMeters: CLLocationDistance?
    @Published private(set) var directionAngle: Double = 0

    private let manager = CLLocationManager()
    private var lastKnownCoordinate: CLLocationCoordinate2D?
    private var currentHeading: CLLocationDirection = 0
    private var canPromptForAuthorization = false

    var activePolygon: [CLLocationCoordinate2D] {
        switch activeTestPolygon {
        case .original:
            return Self.originalRegionPolygon
        case .alternate:
            return Self.alternateRegionPolygon
        case .compact:
            return Self.compactRegionPolygon
        case .southern:
            return Self.southernRegionPolygon
        }
    }

    var activeMapRegion: MKCoordinateRegion {
        Self.mapRegion(for: activePolygon)
    }

    var activePolygonCenter: CLLocationCoordinate2D {
        let latitude = activePolygon.map(\.latitude).reduce(0, +) / Double(activePolygon.count)
        let longitude = activePolygon.map(\.longitude).reduce(0, +) / Double(activePolygon.count)
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var activePolygonName: String {
        switch activeTestPolygon {
        case .original:
            return "Original"
        case .alternate:
            return "Alternative"
        case .compact:
            return "Kompakt"
        case .southern:
            return "Sued"
        }
    }

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.headingFilter = 5
    }

    func requestLocationAccess() {
        authorizationStatus = manager.authorizationStatus
        switch manager.authorizationStatus {
        case .notDetermined:
            statusText = "Standortzugriff noch nicht freigegeben."
        case .authorizedAlways, .authorizedWhenInUse:
            statusText = "Standort wird aktualisiert."
            manager.requestLocation()
            if CLLocationManager.headingAvailable() {
                manager.startUpdatingHeading()
            }
        case .denied, .restricted:
            isInAllowedRegion = false
            statusText = "Standortzugriff ist deaktiviert."
        @unknown default:
            isInAllowedRegion = false
            statusText = "Standortstatus ist unbekannt."
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if hasLocationAccess {
            requestLocationAccess()
        } else if authorizationStatus == .denied || authorizationStatus == .restricted {
            statusText = "Standortzugriff ist deaktiviert."
        }
    }

    var hasLocationAccess: Bool {
        authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse
    }

    func requestAccessForOnboarding() {
        authorizationStatus = manager.authorizationStatus
        canPromptForAuthorization = true
        if authorizationStatus == .notDetermined, canPromptForAuthorization {
            manager.requestWhenInUseAuthorization()
        } else if hasLocationAccess {
            requestLocationAccess()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            isInAllowedRegion = false
            statusText = "Kein Standort verfügbar."
            distanceToRegionText = nil
            distanceToRegionMeters = nil
            return
        }

        lastKnownCoordinate = location.coordinate
        updateRegionState(for: location.coordinate)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let heading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        currentHeading = heading

        if let lastKnownCoordinate {
            updateDistanceAndDirection(for: lastKnownCoordinate)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isInAllowedRegion = false
        statusText = "Standort konnte nicht geladen werden."
        distanceToRegionText = nil
        distanceToRegionMeters = nil
    }

    func toggleTestPolygon() {
        switch activeTestPolygon {
        case .original:
            activeTestPolygon = .alternate
        case .alternate:
            activeTestPolygon = .compact
        case .compact:
            activeTestPolygon = .southern
        case .southern:
            activeTestPolygon = .original
        }
        isUsingTestRegion = true
        if let lastKnownCoordinate {
            updateRegionState(for: lastKnownCoordinate)
        } else {
            requestLocationAccess()
        }
    }

    func clearTestRegion() {
        isUsingTestRegion = false
        activeTestPolygon = .alternate
        if let lastKnownCoordinate {
            updateRegionState(for: lastKnownCoordinate)
        } else {
            statusText = "Standort wird geprüft."
        }
    }

    func distance(to coordinate: CLLocationCoordinate2D) -> CLLocationDistance? {
        guard let lastKnownCoordinate else {
            return nil
        }

        let currentLocation = CLLocation(latitude: lastKnownCoordinate.latitude, longitude: lastKnownCoordinate.longitude)
        let targetLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return currentLocation.distance(from: targetLocation)
    }

    func directionAngle(to coordinate: CLLocationCoordinate2D) -> Double? {
        guard let lastKnownCoordinate else {
            return nil
        }

        let bearing = bearingDegrees(from: lastKnownCoordinate, to: coordinate)
        return bearing - currentHeading
    }

    private func isInsideAllowedPolygon(_ coordinate: CLLocationCoordinate2D) -> Bool {
        let polygonCoordinates = activePolygon
        guard polygonCoordinates.count >= 3 else {
            return false
        }

        var isInside = false
        var previousVertex = polygonCoordinates[polygonCoordinates.count - 1]

        for currentVertex in polygonCoordinates {
            let currentLatitude = currentVertex.latitude
            let currentLongitude = currentVertex.longitude
            let previousLatitude = previousVertex.latitude
            let previousLongitude = previousVertex.longitude

            let crossesLatitude = (currentLatitude > coordinate.latitude) != (previousLatitude > coordinate.latitude)
            if crossesLatitude {
                let longitudeOnEdge = (previousLongitude - currentLongitude) *
                    (coordinate.latitude - currentLatitude) /
                    (previousLatitude - currentLatitude) +
                    currentLongitude

                if coordinate.longitude < longitudeOnEdge {
                    isInside.toggle()
                }
            }

            previousVertex = currentVertex
        }

        return isInside
    }

    private func updateRegionState(for coordinate: CLLocationCoordinate2D) {
        isInAllowedRegion = isInsideAllowedPolygon(coordinate)

        if isUsingTestRegion {
            statusText = isInAllowedRegion
                ? "Testmodus: Dein Standort liegt in der aktiven Region."
                : "Testmodus: Dein Standort liegt außerhalb der aktiven Region."
        } else {
            statusText = isInAllowedRegion
                ? "Du bist in der freigegebenen Region."
                : "Du bist außerhalb der freigegebenen Region."
        }

        updateDistanceAndDirection(for: coordinate)
    }

    private func updateDistanceAndDirection(for coordinate: CLLocationCoordinate2D) {
        let currentLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let targetLocation = CLLocation(latitude: activePolygonCenter.latitude, longitude: activePolygonCenter.longitude)
        let distance = currentLocation.distance(from: targetLocation)
        distanceToRegionMeters = distance

        if distance < 1000 {
            distanceToRegionText = "\(Int(distance.rounded())) m"
        } else {
            distanceToRegionText = String(format: "%.1f km", distance / 1000)
        }

        let bearing = bearingDegrees(from: coordinate, to: activePolygonCenter)
        directionAngle = bearing - currentHeading
    }

    private func bearingDegrees(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> Double {
        let startLatitude = start.latitude * .pi / 180
        let startLongitude = start.longitude * .pi / 180
        let endLatitude = end.latitude * .pi / 180
        let endLongitude = end.longitude * .pi / 180

        let deltaLongitude = endLongitude - startLongitude
        let y = sin(deltaLongitude) * cos(endLatitude)
        let x = cos(startLatitude) * sin(endLatitude) - sin(startLatitude) * cos(endLatitude) * cos(deltaLongitude)
        let bearing = atan2(y, x) * 180 / .pi
        return (bearing + 360).truncatingRemainder(dividingBy: 360)
    }
}
