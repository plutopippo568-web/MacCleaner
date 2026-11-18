import Foundation

struct Item: Identifiable, Hashable {
    let url: URL
    let size: Int64
    let modified: Date?
    var id: URL { url }
    var name: String { url.lastPathComponent }
}

struct AppInfo: Identifiable, Hashable {
    let url: URL
    let name: String
    let bundleID: String?
    let size: Int64
    var id: URL { url }
}

func fmt(_ bytes: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
}

enum DiskScan {
    static var home: URL { FileManager.default.homeDirectoryForCurrentUser }

    static func fileSize(_ u: URL) -> Int64 {
        let v = try? u.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .isRegularFileKey])
        guard v?.isRegularFile == true else { return 0 }
        return Int64(v?.totalFileAllocatedSize ?? 0)
    }

    static func size(of url: URL) -> Int64 {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { return 0 }
        if !isDir.boolValue { return fileSize(url) }
        guard let en = fm.enumerator(at: url, includingPropertiesForKeys: nil,
                                     options: [], errorHandler: { _, _ in true }) else { return 0 }
        var total: Int64 = 0
        for case let u as URL in en { total += fileSize(u) }
        return total
    }

    /// Cache utente, log, DerivedData di Xcode, Cestino.
    static func junk() -> [Item] {
        let roots = [
            home.appendingPathComponent("Library/Caches"),
            home.appendingPathComponent("Library/Logs"),
            home.appendingPathComponent("Library/Developer/Xcode/DerivedData"),
            home.appendingPathComponent(".Trash"),
        ]
        var out: [Item] = []
        for root in roots {
            let kids = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
            for k in kids {
                if k.lastPathComponent.hasPrefix("com.apple.") && root.lastPathComponent == "Caches" { continue }
                let s = size(of: k)
                if s > 0 {
                    let d = try? k.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
                    out.append(Item(url: k, size: s, modified: d))
                }
            }
        }
        return out.sorted { $0.size > $1.size }
    }

    /// File grandi nelle cartelle personali.
    static func large(minBytes: Int64 = 100_000_000) -> [Item] {
        let names = ["Desktop", "Documents", "Downloads", "Movies", "Music", "Pictures"]
        var out: [Item] = []
        for n in names {
            let root = home.appendingPathComponent(n)
            guard let en = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey, .totalFileAllocatedSizeKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { continue }
            for case let u as URL in en {
                let s = fileSize(u)
                if s >= minBytes {
                    let d = try? u.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
                    out.append(Item(url: u, size: s, modified: d))
                }
            }
        }
        return Array(out.sorted { $0.size > $1.size }.prefix(200))
    }

    static func apps() -> [AppInfo] {
        let fm = FileManager.default
        let dirs = [URL(fileURLWithPath: "/Applications"), home.appendingPathComponent("Applications")]
        var out: [AppInfo] = []
        for d in dirs {
            let c = (try? fm.contentsOfDirectory(at: d, includingPropertiesForKeys: nil)) ?? []
            for u in c where u.pathExtension == "app" {
                out.append(AppInfo(url: u,
                                   name: u.deletingPathExtension().lastPathComponent,
                                   bundleID: Bundle(url: u)?.bundleIdentifier,
                                   size: size(of: u)))
            }
        }
        return out.sorted { $0.size > $1.size }
    }

    /// File residui di un'app in ~/Library, cercati per bundle identifier.
    static func leftovers(for app: AppInfo) -> [Item] {
        guard let bid = app.bundleID, bid.count > 5, !bid.hasPrefix("com.apple.") else { return [] }
        let lib = home.appendingPathComponent("Library")
        let dirs = ["Application Support", "Caches", "Preferences", "Containers", "Group Containers",
                    "Logs", "Saved Application State", "HTTPStorages", "WebKit", "Application Scripts"]
        var out: [Item] = []
        for d in dirs {
            let kids = (try? FileManager.default.contentsOfDirectory(at: lib.appendingPathComponent(d), includingPropertiesForKeys: nil)) ?? []
            for k in kids where k.lastPathComponent.contains(bid) {
                out.append(Item(url: k, size: size(of: k), modified: nil))
            }
        }
        return out
    }
}

struct SpaceEntry: Identifiable, Hashable {
    let url: URL
    let size: Int64
    let isDir: Bool
    var id: URL { url }
}

extension DiskScan {
    /// LaunchAgents dell'utente (app che si avviano al login).
    static func agents() -> [Item] {
        let dir = home.appendingPathComponent("Library/LaunchAgents")
        let kids = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        return kids.filter { $0.pathExtension == "plist" }
            .map { Item(url: $0, size: fileSize($0), modified: nil) }
            .sorted { $0.name < $1.name }
    }

    /// Contenuto di una cartella con le dimensioni, ordinato dal più grande.
    static func children(of dir: URL) -> [SpaceEntry] {
        let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey]
        let kids = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: keys)) ?? []
        return kids.compactMap { k -> SpaceEntry? in
            let v = try? k.resourceValues(forKeys: Set(keys))
            if v?.isSymbolicLink == true { return nil }
            return SpaceEntry(url: k, size: size(of: k), isDir: v?.isDirectory ?? false)
        }.sorted { $0.size > $1.size }
    }
}

enum Cleaner {
    /// Rifiuta cartelle di sistema e radici come ~/Library o ~/Documents.
    static func isSafe(_ url: URL) -> Bool {
        let u = url.standardizedFileURL
        let p = u.path
        let parent = u.deletingLastPathComponent().path
        let home = NSHomeDirectory()
        let inHome = p.hasPrefix(home + "/") && parent != home && parent != home + "/Library"
        let inApps = p.hasPrefix("/Applications/") && p.hasSuffix(".app")
        return inHome || inApps
    }

    static func remove(_ urls: [URL], permanent: Bool) -> (removed: Set<URL>, errors: [String]) {
        var removed = Set<URL>()
        var errors: [String] = []
        let fm = FileManager.default
        for u in urls {
            guard isSafe(u) else { errors.append("Protetto: \(u.lastPathComponent)"); continue }
            do {
                if permanent || u.path.contains("/.Trash/") {
                    try fm.removeItem(at: u)
                } else {
                    try fm.trashItem(at: u, resultingItemURL: nil)
                }
                removed.insert(u)
            } catch {
                errors.append("\(u.lastPathComponent): \(error.localizedDescription)")
            }
        }
        return (removed, errors)
    }
}

enum Maintenance: String, CaseIterable, Identifiable {
    case dns = "Svuota cache DNS"
    case spotlight = "Reindicizza Spotlight"
    case launch = "Ricostruisci Launch Services"
    case purge = "Libera memoria inattiva"

    var id: String { rawValue }

    var detail: String {
        switch self {
        case .dns: "Utile se i siti non si aprono o puntano a indirizzi vecchi."
        case .spotlight: "Ricostruisce l'indice di Spotlight (può richiedere del tempo)."
        case .launch: "Risolve voci duplicate in \"Apri con\"."
        case .purge: "Libera la memoria cache inattiva."
        }
    }

    var script: String {
        switch self {
        case .dns: "dscacheutil -flushcache; killall -HUP mDNSResponder"
        case .spotlight: "mdutil -E /"
        case .launch: "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user"
        case .purge: "purge"
        }
    }

    /// Chiede la password di amministratore tramite il dialogo di sistema.
    func run() -> String {
        var err: NSDictionary?
        NSAppleScript(source: "do shell script \"\(script)\" with administrator privileges")?
            .executeAndReturnError(&err)
        if let e = err {
            let msg = e[NSAppleScript.errorMessage] as? String ?? "sconosciuto"
            return "Errore: \(msg)"
        }
        return "\(rawValue): completato"
    }
}
