// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MacCleaner",
    platforms: [.macOS(.v14)],   // gira anche su macOS 27 Golden Gate
    targets: [
        .executableTarget(name: "MacCleaner", path: "Sources/MacCleaner")
    ]
)
