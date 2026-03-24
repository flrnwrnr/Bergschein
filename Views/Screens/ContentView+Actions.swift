import CoreLocation
import MapKit
import SwiftUI
import UIKit

extension ContentView {
    func openMapsToRegion() {
        let coordinate = locationController.activePolygonCenter
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let address = MKAddress(fullAddress: "Berg", shortAddress: nil)
        let mapItem = MKMapItem(location: location, address: address)
        mapItem.name = "Berg"
        mapItem.openInMaps()
    }

    func openMapsToChallengeLocation(_ challenge: DailyChallenge) {
        guard let coordinate = challenge.centerCoordinate else {
            return
        }

        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let address = MKAddress(fullAddress: challenge.locationName, shortAddress: nil)
        let mapItem = MKMapItem(location: location, address: address)
        mapItem.name = challenge.locationName
        mapItem.openInMaps()
    }

    @MainActor
    func makeBadgeShareImage(for presentation: BadgeOverlayPresentation, imageName: String?) -> UIImage? {
        let renderer = ImageRenderer(
            content: BadgeShareGraphicView(
                presentation: presentation,
                imageName: imageName
            )
        )
        renderer.scale = 1
        renderer.proposedSize = ProposedViewSize(width: 1080, height: 1080)
        return renderer.uiImage
    }

    @MainActor
    func makeBergscheinShareImage() -> UIImage? {
        let latestUnlockedBadge = badgeDefinitions.last { unlockedBadges.contains($0.id) }
        let renderer = ImageRenderer(
            content: BergscheinShareGraphicView(
                visitedDays: unlockedBadges.count,
                totalDays: badgeDefinitions.count,
                imageName: latestUnlockedBadge.flatMap { resolvedImageName(for: $0) }
            )
        )
        renderer.scale = 1
        renderer.proposedSize = ProposedViewSize(width: 1080, height: 1080)
        return renderer.uiImage
    }

    func triggerLightHaptic() {
        guard hapticsEnabled else {
            return
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func triggerSelectionHaptic() {
        guard hapticsEnabled else {
            return
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func triggerSuccessHaptic() {
        guard hapticsEnabled else {
            return
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func triggerWarningHaptic() {
        guard hapticsEnabled else {
            return
        }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}
