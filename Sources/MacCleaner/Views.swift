import SwiftUI

enum Page: String, CaseIterable, Identifiable {
    case smart = "Scansione intelligente"
    case junk = "Pulizia sistema"
    case large = "File grandi"
    case apps = "Disinstallazione"
    case agents = "Elementi di avvio"
    case space = "Spazio su disco"
    case maint = "Manutenzione"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .smart: "sparkles"
        case .junk: "trash"
        case .large: "doc.richtext"
        case .apps: "xmark.app"
        case .agents: "power"
        case .space: "chart.pie"
        case .maint: "wrench.and.screwdriver"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var model: CleanerModel
    @State private var page: Page? = .smart

    var body: some View {
        NavigationSplitView {
            List(Page.allCases, selection: $page) { p in
                Label(p.rawValue, systemImage: p.icon).tag(p)
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 230)
        } detail: {
            switch page ?? .smart {
            case .smart:
                SmartView()
            case .junk:
                CleanPage(title: "Pulizia sistema", items: model.junk, permanent: true) { await model.scanJunk() }
            case .large:
                CleanPage(title: "File grandi (> 100 MB)", items: model.large, permanent: false) { await model.scanLarge() }
            case .apps:
                AppsPage()
            case .agents:
                CleanPage(title: "Elementi di avvio (LaunchAgents utente)", items: model.agents, permanent: false) { await model.scanAgents() }
            case .space:
                SpacePage()
            case .maint:
                MaintPage()
            }
        }
    }
}

struct SmartView: View {
    @EnvironmentObject var model: CleanerModel

    var disk: (total: Int64, free: Int64) {
        let v = try? URL(fileURLWithPath: "/").resourceValues(
            forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey])
        return (Int64(v?.volumeTotalCapacity ?? 0), v?.volumeAvailableCapacityForImportantUsage ?? 0)
    }

    var body: some View {
        let d = disk
        let used = max(d.total - d.free, 0)
        VStack(alignment: .leading, spacing: 16) {
            Text("Scansione intelligente").font(.largeTitle.bold())
            ProgressView(value: d.total > 0 ? Double(used) / Double(d.total) : 0)
            Text("Disco: \(fmt(used)) usati · \(fmt(d.free)) liberi su \(fmt(d.total))")
                .foregroundStyle(.secondary)
            Divider()
            Text("Da pulire: \(fmt(model.junk.reduce(0) { $0 + $1.size }))  (\(model.junk.count) elementi)")
            Text("File grandi: \(fmt(model.large.reduce(0) { $0 + $1.size }))  (\(model.large.count) file)")
            HStack {
                Button("Avvia scansione") {
                    Task { await model.scanJunk(); await model.scanLarge() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.busy)
                if model.busy { ProgressView().controlSize(.small) }
            }
            Text("Poi apri \"Pulizia sistema\" o \"File grandi\" per scegliere cosa eliminare.")
                .font(.caption).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(24)
    }
}

struct CleanPage: View {
    @EnvironmentObject var model: CleanerModel
    let title: String
    let items: [Item]
    var permanent = false
    let scan: () async -> Void
    @State private var confirm = false

    var chosen: [Item] { items.filter { model.selected.contains($0.id) } }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).font(.title2.bold())
                Spacer()
                if model.busy { ProgressView().controlSize(.small) }
                Button("Scansiona") { Task { await scan() } }.disabled(model.busy)
            }
            .padding()

            List(items) { item in
                HStack {
                    Toggle("", isOn: Binding(
                        get: { model.selected.contains(item.id) },
                        set: { on in
                            if on { model.selected.insert(item.id) } else { model.selected.remove(item.id) }
                        })).labelsHidden()
                    VStack(alignment: .leading) {
                        Text(item.name)
                        Text(item.url.path).font(.caption).foregroundStyle(.secondary)
                            .lineLimit(1).truncationMode(.middle)
                    }
                    Spacer()
                    Text(fmt(item.size)).monospacedDigit()
                }
            }

            Divider()
            HStack {
                Button("Seleziona tutto") { model.selected.formUnion(items.map(\.id)) }
                Button("Deseleziona") { model.selected.subtract(items.map(\.id)) }
                Spacer()
                Text(model.message).foregroundStyle(.secondary)
                Button(permanent ? "Elimina (\(fmt(chosen.reduce(0) { $0 + $1.size })))"
                                 : "Sposta nel Cestino (\(fmt(chosen.reduce(0) { $0 + $1.size })))") {
                    confirm = true
                }
                .disabled(chosen.isEmpty || model.busy)
            }
            .padding()
        }
        .confirmationDialog(permanent ? "Eliminare definitivamente \(chosen.count) elementi?"
                                      : "Spostare \(chosen.count) elementi nel Cestino?",
                            isPresented: $confirm) {
            Button(permanent ? "Elimina" : "Sposta nel Cestino", role: .destructive) {
                model.remove(chosen, permanent: permanent)
            }
        }
    }
}

struct AppsPage: View {
    @EnvironmentObject var model: CleanerModel
    @State private var sel: AppInfo?
    @State private var left: [Item] = []
    @State private var confirm = false

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                HStack {
                    Text("Disinstallazione").font(.title2.bold())
                    Spacer()
                    if model.busy { ProgressView().controlSize(.small) }
                    Button("Scansiona") { Task { await model.scanApps() } }.disabled(model.busy)
                }
                .padding()
                List(model.apps, selection: $sel) { a in
                    HStack { Text(a.name); Spacer(); Text(fmt(a.size)).monospacedDigit() }.tag(a)
                }
            }
            .frame(minWidth: 320)

            VStack(alignment: .leading, spacing: 10) {
                if let a = sel {
                    Text(a.name).font(.title3.bold())
                    Text(a.bundleID ?? "—").font(.caption).foregroundStyle(.secondary)
                    Text("File residui trovati: \(left.count) (\(fmt(left.reduce(0) { $0 + $1.size })))")
                    List(left) { i in
                        HStack { Text(i.url.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                                    .lineLimit(1).truncationMode(.middle)
                                 Spacer(); Text(fmt(i.size)) }
                    }
                    Button("Disinstalla (nel Cestino)") { confirm = true }
                        .buttonStyle(.borderedProminent).disabled(model.busy)
                    Text(model.message).foregroundStyle(.secondary)
                } else {
                    Text("Scansiona e seleziona un'app").foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding()
            .frame(minWidth: 320)
        }
        .task(id: sel) {
            if let a = sel { left = await Task.detached { DiskScan.leftovers(for: a) }.value } else { left = [] }
        }
        .confirmationDialog("Spostare l'app e i suoi file residui nel Cestino?", isPresented: $confirm) {
            Button("Disinstalla", role: .destructive) {
                if let a = sel {
                    model.remove([Item(url: a.url, size: a.size, modified: nil)] + left, permanent: false)
                    sel = nil
                }
            }
        }
    }
}

struct SpacePage: View {
    @State private var dir = DiskScan.home
    @State private var entries: [SpaceEntry] = []
    @State private var loading = false

    var body: some View {
        let maxSize = Double(max(entries.first?.size ?? 1, 1))
        VStack(spacing: 0) {
            HStack {
                Button { dir = dir.deletingLastPathComponent() } label: { Image(systemName: "chevron.up") }
                    .disabled(dir.path == "/")
                Text(dir.path).lineLimit(1).truncationMode(.head)
                Spacer()
                if loading { ProgressView().controlSize(.small) }
                Button("Home") { dir = DiskScan.home }
            }
            .padding()

            List(entries) { e in
                HStack {
                    Image(systemName: e.isDir ? "folder" : "doc")
                    Text(e.url.lastPathComponent).lineLimit(1).frame(width: 220, alignment: .leading)
                    GeometryReader { g in
                        Capsule().fill(.tint)
                            .frame(width: g.size.width * CGFloat(Double(e.size) / maxSize))
                    }
                    .frame(height: 8)
                    Text(fmt(e.size)).monospacedDigit().frame(width: 80, alignment: .trailing)
                    Button("Apri") { dir = e.url }.disabled(!e.isDir)
                    Button { NSWorkspace.shared.activateFileViewerSelecting([e.url]) } label: {
                        Image(systemName: "magnifyingglass")
                    }
                }
            }
        }
        .task(id: dir) {
            loading = true
            entries = await Task.detached { [dir] in DiskScan.children(of: dir) }.value
            loading = false
        }
    }
}

struct MaintPage: View {
    @State private var status = ""

    var body: some View {
        VStack(alignment: .leading) {
            Text("Manutenzione").font(.title2.bold()).padding([.top, .horizontal])
            List(Maintenance.allCases) { m in
                HStack {
                    VStack(alignment: .leading) {
                        Text(m.rawValue).font(.headline)
                        Text(m.detail).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Esegui") { status = m.run() }
                }
            }
            Text(status).foregroundStyle(.secondary).padding()
        }
    }
}
