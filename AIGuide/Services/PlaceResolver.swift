import Foundation
import CoreLocation
import MapKit

struct GlobalKnownDestination {
    let id: String
    let name: String
    let localName: String?
    let subtitle: String
    let address: String
    let coordinate: CLLocationCoordinate2D
    let searchQuery: String
    let aliases: [String]
    let disambiguators: [String]
    let countryCode: String
    let popularity: Int

    var displayName: String {
        L10n.string("destination.\(id).name")
    }

    var displaySubtitle: String {
        L10n.string("destination.\(id).subtitle")
    }

    var displayAddress: String {
        L10n.string("destination.\(id).address")
    }
}

struct GlobalPlaceResolver {
    static let shared = GlobalPlaceResolver()

    let knownDestinations: [GlobalKnownDestination] = [
        GlobalKnownDestination(
            id: "louvre-paris",
            name: "卢浮宫博物馆",
            localName: "Musée du Louvre",
            subtitle: "巴黎 · 法国",
            address: "Rue de Rivoli, 75001 Paris, France",
            coordinate: CLLocationCoordinate2D(latitude: 48.8606, longitude: 2.3376),
            searchQuery: "Louvre Museum Paris France",
            aliases: ["卢浮宫", "卢浮宫博物馆", "巴黎卢浮宫", "louvre", "louvre museum", "musee du louvre", "musée du louvre"],
            disambiguators: ["巴黎", "法国", "paris", "france", "rue de rivoli"],
            countryCode: "FR",
            popularity: 100
        ),
        GlobalKnownDestination(
            id: "forbidden-city-beijing",
            name: "故宫博物院",
            localName: "The Palace Museum",
            subtitle: "北京 · 中国",
            address: "北京市东城区景山前街4号",
            coordinate: CLLocationCoordinate2D(latitude: 39.9163, longitude: 116.3972),
            searchQuery: "故宫博物院 北京",
            aliases: ["故宫", "故宫博物院", "北京故宫", "紫禁城", "forbidden city", "palace museum beijing"],
            disambiguators: ["北京", "东城", "紫禁城", "beijing"],
            countryCode: "CN",
            popularity: 98
        ),
        GlobalKnownDestination(
            id: "national-palace-museum-taipei",
            name: "台北故宫博物院",
            localName: "National Palace Museum",
            subtitle: "台北 · 中国台湾",
            address: "台北市士林区至善路二段221号",
            coordinate: CLLocationCoordinate2D(latitude: 25.1024, longitude: 121.5485),
            searchQuery: "National Palace Museum Taipei",
            aliases: ["故宫", "台北故宫", "台北故宫博物院", "国立故宫博物院", "國立故宮博物院", "national palace museum"],
            disambiguators: ["台北", "士林", "taipei", "taiwan"],
            countryCode: "TW",
            popularity: 88
        ),
        GlobalKnownDestination(
            id: "met-museum-new-york",
            name: "大都会艺术博物馆",
            localName: "The Metropolitan Museum of Art",
            subtitle: "纽约 · 美国",
            address: "1000 5th Ave, New York, NY 10028",
            coordinate: CLLocationCoordinate2D(latitude: 40.7794, longitude: -73.9632),
            searchQuery: "The Metropolitan Museum of Art New York",
            aliases: ["大都会艺术博物馆", "大都会博物馆", "纽约大都会艺术博物馆", "met museum", "the met", "metropolitan museum of art"],
            disambiguators: ["纽约", "美国", "new york", "nyc", "usa"],
            countryCode: "US",
            popularity: 93
        ),
        GlobalKnownDestination(
            id: "contemporary-jewish-museum-san-francisco",
            name: "Contemporary Jewish Museum",
            localName: nil,
            subtitle: "旧金山 · 美国",
            address: "736 Mission St, San Francisco, CA 94103",
            coordinate: CLLocationCoordinate2D(latitude: 37.7858, longitude: -122.4034),
            searchQuery: "Contemporary Jewish Museum San Francisco",
            aliases: ["contemporary jewish museum", "当代犹太博物馆", "旧金山当代犹太博物馆"],
            disambiguators: ["旧金山", "san francisco", "sf", "mission st"],
            countryCode: "US",
            popularity: 72
        ),
        GlobalKnownDestination(
            id: "british-museum-london",
            name: "大英博物馆",
            localName: "The British Museum",
            subtitle: "伦敦 · 英国",
            address: "Great Russell St, London WC1B 3DG, United Kingdom",
            coordinate: CLLocationCoordinate2D(latitude: 51.5194, longitude: -0.1270),
            searchQuery: "British Museum London",
            aliases: ["大英博物馆", "british museum", "伦敦大英博物馆"],
            disambiguators: ["伦敦", "英国", "london", "uk", "united kingdom"],
            countryCode: "GB",
            popularity: 95
        ),
        GlobalKnownDestination(
            id: "tokyo-national-museum",
            name: "东京国立博物馆",
            localName: "東京国立博物館",
            subtitle: "东京 · 日本",
            address: "13-9 Uenokoen, Taito City, Tokyo",
            coordinate: CLLocationCoordinate2D(latitude: 35.7188, longitude: 139.7765),
            searchQuery: "Tokyo National Museum",
            aliases: ["东京国立博物馆", "東京国立博物館", "tokyo national museum", "tnm"],
            disambiguators: ["东京", "上野", "tokyo", "ueno", "japan"],
            countryCode: "JP",
            popularity: 86
        )
    ]

    func knownDestinations(matching query: String) -> [GlobalKnownDestination] {
        let normalizedQuery = normalized(query)
        guard !normalizedQuery.isEmpty else { return [] }

        let matches = knownDestinations.compactMap { destination -> (GlobalKnownDestination, Int)? in
            let aliasTokens = destination.aliases.map(normalized)
            let disambiguatorTokens = destination.disambiguators.map(normalized)
            let exactAlias = aliasTokens.contains(normalizedQuery)
            let containedAlias = aliasTokens.contains { alias in
                !alias.isEmpty && (normalizedQuery.contains(alias) || alias.contains(normalizedQuery))
            }
            let hasDisambiguator = disambiguatorTokens.contains { clue in
                !clue.isEmpty && normalizedQuery.contains(clue)
            }

            guard exactAlias || containedAlias || hasDisambiguator else { return nil }

            var score = destination.popularity
            if exactAlias { score += 80 }
            if hasDisambiguator { score += 40 }
            if containedAlias { score += 20 }
            return (destination, score)
        }

        return matches
            .sorted { lhs, rhs in
                if lhs.1 == rhs.1 {
                    return lhs.0.popularity > rhs.0.popularity
                }
                return lhs.1 > rhs.1
            }
            .map(\.0)
    }

    func shouldKeepMapResult(name: String, subtitle: String, category: MKPointOfInterestCategory?) -> Bool {
        tourismScore(name: name, subtitle: subtitle, category: category, query: nil) > 0
    }

    func rankedMapItems(_ mapItems: [MKMapItem], query: String) -> [MKMapItem] {
        mapItems
            .compactMap { item -> (MKMapItem, Int)? in
                guard let name = item.name?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !name.isEmpty else {
                    return nil
                }

                let score = tourismScore(
                    name: name,
                    subtitle: item.placemark.title ?? "",
                    category: item.pointOfInterestCategory,
                    query: query
                )
                guard score > 0 else { return nil }
                return (item, score)
            }
            .sorted { first, second in
                if first.1 == second.1 {
                    return (first.0.name ?? "") < (second.0.name ?? "")
                }
                return first.1 > second.1
            }
            .map(\.0)
    }

    func tourismScore(
        name: String,
        subtitle: String,
        category: MKPointOfInterestCategory?,
        query: String?
    ) -> Int {
        let text = normalized("\(name) \(subtitle)")
        let normalizedName = normalized(name)
        let normalizedQuery = normalized(query ?? "")

        if excludedPlaceTerms.contains(where: { !normalized($0).isEmpty && text.contains(normalized($0)) }) {
            return -100
        }

        var score = 0
        if let category,
           culturalCategories.contains(category) {
            score += 70
        }

        if tourismTerms.contains(where: { term in
            !normalized(term).isEmpty && text.contains(normalized(term))
        }) {
            score += 55
        }

        if !normalizedQuery.isEmpty {
            if normalizedName == normalizedQuery {
                score += 12
            } else if normalizedName.contains(normalizedQuery) || normalizedQuery.contains(normalizedName) {
                score += 8
            }
        }

        let knownMatches = query.map(knownDestinations(matching:)) ?? []
        if !knownMatches.isEmpty {
            let matchesKnownDestination = knownMatches.contains { destination in
                let knownTokens = ([destination.name, destination.localName, destination.subtitle, destination.address] +
                    destination.disambiguators + destination.aliases)
                    .compactMap { $0 }
                    .map(normalized)

                return knownTokens.contains { token in
                    !token.isEmpty && (text.contains(token) || normalizedName.contains(token))
                }
            }

            if matchesKnownDestination {
                score += 80
            } else if score < 70 {
                // Queries such as "卢浮宫" should not surface unrelated residential or commercial
                // places that happen to share the famous name.
                score -= 60
            }
        }

        return score
    }

    func normalized(_ text: String) -> String {
        text
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "[^\\p{L}\\p{N}]+", with: "", options: .regularExpression)
    }

    var culturalCategories: Set<MKPointOfInterestCategory> {
        [
            .museum,
            .nationalPark,
            .park,
            .theater,
            .zoo,
            .aquarium,
            .beach,
            .campground,
            .marina,
            .stadium
        ]
    }

    private var excludedPlaceTerms: [String] {
        [
            "住宅", "小区", "公寓", "楼盘", "别墅", "房产", "房地产", "售楼",
            "物业", "社区", "家园", "生活区", "商住", "写字楼", "办公楼",
            "工业园", "产业园", "公司", "装修", "建材", "家居", "apartment",
            "residence", "residential", "real estate", "property", "office"
        ]
    }

    private var tourismTerms: [String] {
        [
            "博物馆", "博物院", "美术馆", "艺术馆", "纪念馆", "展览馆", "展馆",
            "景区", "景点", "风景区", "名胜", "地标", "遗址", "古迹", "古城",
            "公园", "国家公园", "动物园", "植物园", "水族馆", "海洋馆",
            "剧院", "剧场", "寺", "庙", "陵", "塔", "故宫", "宫殿",
            "museum", "gallery", "landmark", "attraction", "monument", "palace",
            "park", "theater", "theatre", "historic", "heritage", "temple",
            "castle", "cathedral", "shrine", "garden"
        ]
    }
}
