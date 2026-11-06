import Foundation

struct WidgetSnapshot: Codable {
    var temperature: Double?
    var measuredAt: String?
    var medication: String?
    var nurofenAt: String?
    var tachipirinaAt: String?
    var antibioticoAt: String?
    var updatedAt: String

    static let appGroup = "group.it.diariotemperatura.shared"
    static let storageKey = "diario-temperatura.widget.snapshot"

    static func load() -> WidgetSnapshot? {
        guard
            let defaults = UserDefaults(suiteName: appGroup),
            let data = defaults.data(forKey: storageKey)
        else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    func save() {
        guard
            let defaults = UserDefaults(suiteName: Self.appGroup),
            let data = try? JSONEncoder().encode(self)
        else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}

struct CloudMeasurement: Decodable {
    let temperature: Double
    let measured_at: String
    let medication: String
}
