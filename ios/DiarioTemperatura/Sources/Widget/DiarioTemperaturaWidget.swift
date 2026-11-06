import SwiftUI
import WidgetKit

struct TemperatureEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

struct TemperatureProvider: TimelineProvider {
    func placeholder(in context: Context) -> TemperatureEntry {
        TemperatureEntry(date: Date(), snapshot: WidgetSnapshot(
            temperature: 38.2,
            measuredAt: ISO8601DateFormatter().string(from: Date()),
            medication: "Tachipirina",
            nurofenAt: nil,
            tachipirinaAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600)),
            antibioticoAt: nil,
            updatedAt: ISO8601DateFormatter().string(from: Date())
        ))
    }

    func getSnapshot(in context: Context, completion: @escaping (TemperatureEntry) -> Void) {
        completion(TemperatureEntry(date: Date(), snapshot: WidgetSnapshot.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TemperatureEntry>) -> Void) {
        let entry = TemperatureEntry(date: Date(), snapshot: WidgetSnapshot.load())
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(15 * 60))))
    }
}

struct TemperatureWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TemperatureEntry

    var body: some View {
        Group {
            if let snapshot = entry.snapshot {
                switch family {
                case .systemSmall:
                    small(snapshot)
                case .systemLarge, .systemExtraLarge:
                    large(snapshot)
                default:
                    medium(snapshot)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Diario temperatura", systemImage: "thermometer.medium").font(.caption.bold())
                    Text("Apri l'app per sincronizzare").font(.caption).foregroundStyle(.secondary)
                }
                .padding()
            }
        }
        .widgetURL(URL(string: "diariotemperatura://"))
        .containerBackground(.background, for: .widget)
    }

    private func small(_ snapshot: WidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Label("Temperatura", systemImage: "thermometer.medium").font(.caption2.bold()).foregroundStyle(.secondary)
            Text(snapshot.temperature.map { String(format: "%.1f°", $0) } ?? "—")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(snapshot.measuredAt?.widgetDate ?? "Nessuna rilevazione")
                .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(2)
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 2) {
                Text("Nurofen: \(snapshot.nurofenAt?.elapsed ?? "—")")
                Text("Tachipirina: \(snapshot.tachipirinaAt?.elapsed ?? "—")")
                Text("Antibiotico: \(snapshot.antibioticoAt?.elapsed ?? "—")")
            }
            .font(.system(size: 8, weight: .medium, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        .padding()
    }

    private func medium(_ snapshot: WidgetSnapshot) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("ULTIMA TEMPERATURA").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary)
                Text(snapshot.temperature.map { String(format: "%.1f°", $0) } ?? "—")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                Text(snapshot.measuredAt?.widgetDate ?? "Nessuna rilevazione").font(.system(size: 10)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            VStack(alignment: .leading, spacing: 7) {
                timerLine("Nurofen", snapshot.nurofenAt)
                timerLine("Tachipirina", snapshot.tachipirinaAt)
                timerLine("Antibiotico", snapshot.antibioticoAt)
            }
        }
        .padding()
    }

    private func large(_ snapshot: WidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Diario temperatura", systemImage: "thermometer.medium").font(.headline)
                Spacer()
                Text("CLOUD").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(snapshot.temperature.map { String(format: "%.1f°", $0) } ?? "—")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                Text(snapshot.measuredAt?.widgetDate ?? "Nessuna rilevazione").font(.caption).foregroundStyle(.secondary)
            }
            Divider()
            Text("TEMPO DALL'ULTIMA ASSUNZIONE").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary)
            timerLine("Nurofen", snapshot.nurofenAt)
            timerLine("Tachipirina", snapshot.tachipirinaAt)
            timerLine("Antibiotico", snapshot.antibioticoAt)
            Spacer(minLength: 0)
            Text("Aggiornato: \(snapshot.updatedAt.widgetDate)").font(.system(size: 9)).foregroundStyle(.tertiary)
        }
        .padding()
    }

    private func timerLine(_ title: String, _ value: String?) -> some View {
        HStack {
            Text(title).font(.caption)
            Spacer()
            Text(value?.elapsed ?? "—").font(.caption.bold().monospacedDigit()).foregroundStyle(.secondary)
        }
    }
}

private extension String {
    var widgetParsedDate: Date? {
        ISO8601DateFormatter.withFractionalSeconds.date(from: self) ?? ISO8601DateFormatter().date(from: self)
    }

    var widgetDate: String {
        guard let date = widgetParsedDate else { return self }
        return date.formatted(date: .numeric, time: .shortened)
    }

    var elapsed: String {
        guard let date = widgetParsedDate else { return "—" }
        let minutes = max(0, Int(Date().timeIntervalSince(date) / 60))
        let days = minutes / 1440
        let hours = (minutes % 1440) / 60
        let remainder = minutes % 60
        if days > 0 { return "\(days)g \(hours)h \(remainder)m" }
        if hours > 0 { return "\(hours)h \(remainder)m" }
        return "\(remainder) min"
    }
}

private extension ISO8601DateFormatter {
    static let withFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

struct DiarioTemperaturaWidget: Widget {
    let kind = "DiarioTemperaturaWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TemperatureProvider()) { entry in
            TemperatureWidgetView(entry: entry)
        }
        .configurationDisplayName("Diario temperatura")
        .description("Ultima temperatura e timer dei farmaci.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct DiarioTemperaturaWidgetBundle: WidgetBundle {
    var body: some Widget {
        DiarioTemperaturaWidget()
    }
}
