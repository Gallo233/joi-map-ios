// Share Service - Social Sharing

import Foundation
import UIKit

@MainActor
class ShareService: ObservableObject {
    // MARK: - Singleton
    static let shared = ShareService()
    
    // MARK: - Types
    struct ShareContent {
        let title: String
        let description: String
        let image: UIImage?
        let url: URL?
    }
    
    // MARK: - Public Methods
    
    /// Share POI
    func sharePOI(_ poi: POI) {
        let content = ShareContent(
            title: L10n.format("share.poi.title.format", poi.name),
            description: poi.description,
            image: nil,
            url: URL(string: "https://aiguide.app/poi/\(poi.id)")
        )
        
        shareContent(content)
    }
    
    /// Share tour
    func shareTour(_ tour: TourService.Tour) {
        let content = ShareContent(
            title: L10n.format("share.tour.title.format", tour.name),
            description: L10n.format("share.tour.description.format", tour.description, tour.stopCount, tour.formattedDuration),
            image: nil,
            url: URL(string: "https://aiguide.app/tour/\(tour.id)")
        )
        
        shareContent(content)
    }
    
    /// Share visit record
    func shareVisit(_ record: HistoryService.VisitRecord) {
        let content = ShareContent(
            title: L10n.format("share.visit.title.format", record.poiName),
            description: L10n.format("share.visit.description.format", record.formattedDuration),
            image: nil,
            url: URL(string: "https://aiguide.app/visit/\(record.id)")
        )
        
        shareContent(content)
    }
    
    /// Share app
    func shareApp() {
        let content = ShareContent(
            title: L10n.string("share.app.title"),
            description: L10n.string("share.app.description"),
            image: nil,
            url: URL(string: "https://apps.apple.com/app/aiguide")
        )
        
        shareContent(content)
    }
    
    // MARK: - Private Methods
    
    private func shareContent(_ content: ShareContent) {
        var items: [Any] = []
        
        if let url = content.url {
            items.append(url)
        }
        
        if !content.description.isEmpty {
            items.append(content.description)
        }
        
        if let image = content.image {
            items.append(image)
        }
        
        guard !items.isEmpty else { return }
        
        let activityVC = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        
        // Present
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}
