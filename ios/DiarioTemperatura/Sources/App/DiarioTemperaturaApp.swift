import SwiftUI
import Supabase
import WidgetKit
import BackgroundTasks
import UIKit
import Combine

private enum CloudConfig {
    static let url = URL(string: "https://muuihmayqnvzugomfwlq.supabase.co")!
    // Publishable key: intended for client applications; row access remains protected by Supabase Auth + RLS.
    static let publishableKey = "sb_publishable_QLIN1H0b8iNL7Rekwl9ZHA_KayB6Mcd"
    static let backgroundTask = "it.diariotemperatura.app.refresh"
}

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    @Published var isSignedIn = false
    @Published var email = ""
    @Published var password = ""
    @Published var status = "Accedi con lo stesso account della versione cloud."
    @Published var snapshot: WidgetSnapshot?

    private let client = SupabaseClient(supabaseURL: CloudConfig.url, supabaseKey: CloudConfig.publishableKey)

    private init() {
        snapshot = WidgetSnapshot.load()
    }

    func restoreSession() async {
        do {
            _ = try await client.auth.session
            isSignedIn = true
            await refresh()
        } catch {
            isSignedIn = false
        }
    }

    func signIn() async {
        guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !password.isEmpty else {
            status = "Inserisci email e password."
            return
        }
        do {
            try await client.auth.signIn(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
            isSignedIn = true
            password = ""
            await refresh()
        } catch {
            status = "Accesso non riuscito: \(error.localizedDescription)"
        }
    }

    func signOut() async {
        do {
            try await client.auth.signOut()
            isSignedIn = false
            status = "Sessione terminata."
        } catch {
            status = error.localizedDescription
        }
    }

    func refresh() async {
        do {
            _ = try await client.auth.session
            async let latest = latestMeasurement(medication: nil)
            async let nurofen = latestMeasurement(medication: "Nurofen")
            async let tachipirina = latestMeasurement(medication: "Tachipirina")
            async let antibiotico = latestMeasurement(medication: "Antibiotico")
            let (last, n, t, a) = try await (latest, nurofen, tachipirina, antibiotico)
            let next = WidgetSnapshot(
                temperature: last?.temperature,
                measuredAt: last?.measured_at,
                medication: last?.medication,
                nurofenAt: n?.measured_at,
                tachipirinaAt: t?.measured_at,
                antibioticoAt: a?.measured_at,
                updatedAt: ISO8601DateFormatter().string(from: Date())
            )
            next.save()
            snapshot = next
            isSignedIn = true
            status = "Sincronizzato alle \(Date().formatted(date: .omitted, time: .shortened))."
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            status = "Sincronizzazione non riuscita: \(error.localizedDescription)"
            isSignedIn = false
        }
    }

    private func latestMeasurement(medication: String?) async throws -> CloudMeasurement? {
        let rows: [CloudMeasurement]
        if let medication {
            rows = try await client.from("fever_measurements")
                .select("temperature,measured_at,medication")
                .eq("medication", value: medication)
                .order("measured_at", ascending: false)
                .limit(1)
                .execute()
                .value
        } else {
            rows = try await client.from("fever_measurements")
                .select("temperature,measured_at,medication")
                .order("measured_at", ascending: false)
                .limit(1)
                .execute()
                .value
        }
        return rows.first
    }

    func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: CloudConfig.backgroundTask)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 20 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    func runBackgroundRefresh(_ task: BGAppRefreshTask) {
        scheduleBackgroundRefresh()
        let operation = Task { @MainActor in
            await refresh()
            task.setTaskCompleted(success: snapshot != nil)
            scheduleBackgroundRefresh()
        }
        task.expirationHandler = { operation.cancel() }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: CloudConfig.backgroundTask, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            Task { @MainActor in
                AppModel.shared.runBackgroundRefresh(refreshTask)
            }
        }
        AppModel.shared.scheduleBackgroundRefresh()
        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        AppModel.shared.scheduleBackgroundRefresh()
    }
}

@main
struct DiarioTemperaturaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model = AppModel.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        Task { await model.restoreSession() }
                    }
                }
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var didRestore = false

    var body: some View {
        Group {
            if model.isSignedIn {
                DashboardView()
            } else {
                LoginView()
            }
        }
        .task {
            guard !didRestore else { return }
            didRestore = true
            await model.restoreSession()
        }
    }
}

struct LoginView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "thermometer.medium").font(.system(size: 42, weight: .medium)).foregroundStyle(.red)
            Text("Diario temperatura").font(.largeTitle.bold())
            Text("Accedi con le credenziali della nuova app cloud.").foregroundStyle(.secondary).multilineTextAlignment(.center)
            TextField("Email", text: $model.email).textContentType(.emailAddress).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled().textFieldStyle(.roundedBorder)
            SecureField("Password", text: $model.password).textContentType(.password).textFieldStyle(.roundedBorder)
            Button { Task { await model.signIn() } } label: {
                Text("Accedi").frame(maxWidth: .infinity).padding(.vertical, 5)
            }.buttonStyle(.borderedProminent)
            Text(model.status).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding(24)
    }
}

struct DashboardView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack {
            List {
                Section("Ultima misurazione") {
                    if let value = model.snapshot?.temperature {
                        HStack(alignment: .firstTextBaseline) {
                            Text(String(format: "%.1f °C", value)).font(.system(size: 38, weight: .bold, design: .rounded))
                            Spacer()
                            Text(model.snapshot?.medication ?? "Nessun farmaco").font(.subheadline).foregroundStyle(.secondary)
                        }
                        if let date = model.snapshot?.measuredAt {
                            Text("Registrata il \(date.formattedCloudDate)").font(.footnote).foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Nessuna misurazione disponibile.")
                    }
                }
                Section("Timer farmaci") {
                    TimerRow(name: "Nurofen", date: model.snapshot?.nurofenAt)
                    TimerRow(name: "Tachipirina", date: model.snapshot?.tachipirinaAt)
                    TimerRow(name: "Antibiotico", date: model.snapshot?.antibioticoAt)
                }
                Section {
                    Button { Task { await model.refresh() } } label: {
                        Label("Sincronizza adesso", systemImage: "arrow.clockwise")
                    }
                    Text(model.status).font(.footnote).foregroundStyle(.secondary)
                    Button("Esci", role: .destructive) { Task { await model.signOut() } }
                }
            }
            .navigationTitle("Diario temperatura")
        }
    }
}

struct TimerRow: View {
    let name: String
    let date: String?

    var body: some View {
        HStack {
            Text(name)
            Spacer()
            Text(date.map { $0.elapsedLabel } ?? "—").monospacedDigit().foregroundStyle(.secondary)
        }
    }
}

private extension String {
    var parsedCloudDate: Date? {
        ISO8601DateFormatter().date(from: self)
            ?? ISO8601DateFormatter.withFractionalSeconds.date(from: self)
    }

    var formattedCloudDate: String {
        guard let date = parsedCloudDate else { return self }
        return date.formatted(date: .numeric, time: .shortened)
    }

    var elapsedLabel: String {
        guard let date = parsedCloudDate else { return "—" }
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
