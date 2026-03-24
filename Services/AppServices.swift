//
//  AppServices.swift
//  Bergschein
//

import Combine
import CoreLocation
import MapKit
import StoreKit
import SwiftUI

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
