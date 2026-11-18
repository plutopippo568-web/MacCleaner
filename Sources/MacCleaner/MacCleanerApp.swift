import SwiftUI

@main
struct MacCleanerApp: App {
    @StateObject private var model = CleanerModel()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 900, minHeight: 580)
        }
    }
}

@MainActor
final class CleanerModel: ObservableObject {
    @Published var junk: [Item] = []
    @Published var large: [Item] = []
    @Published var apps: [AppInfo] = []
    @Published var agents: [Item] = []
    @Published var selected = Set<URL>()
    @Published var busy = false
    @Published var message = ""

    func scanJunk() async {
        busy = true; message = ""
        junk = await Task.detached { DiskScan.junk() }.value
        busy = false
    }

    func scanLarge() async {
        busy = true; message = ""
        large = await Task.detached { DiskScan.large() }.value
        busy = false
    }

    func scanAgents() async {
        busy = true; message = ""
        agents = await Task.detached { DiskScan.agents() }.value
        busy = false
    }

    func scanApps() async {
        busy = true; message = ""
        apps = await Task.detached { DiskScan.apps() }.value
        busy = false
    }

    func remove(_ items: [Item], permanent: Bool) {
        busy = true
        let urls = items.map(\.url)
        Task {
            let r = await Task.detached { Cleaner.remove(urls, permanent: permanent) }.value
            let gone = r.removed
            let freed = items.filter { gone.contains($0.url) }.reduce(Int64(0)) { $0 + $1.size }
            junk.removeAll { gone.contains($0.url) }
            large.removeAll { gone.contains($0.url) }
            apps.removeAll { gone.contains($0.url) }
            agents.removeAll { gone.contains($0.url) }
            selected.subtract(gone)
            message = "Liberati \(fmt(freed))" + (r.errors.isEmpty ? "" : " · \(r.errors.count) errori (vedi permessi)")
            busy = false
        }
    }
}
