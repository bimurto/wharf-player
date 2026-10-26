// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SftpMediaPlayerNative",
    platforms: [.macOS(.v14)],
    targets: [
        .systemLibrary(name: "CMPV", pkgConfig: "mpv", providers: [.brew(["mpv"])]),
        .systemLibrary(name: "CLibSSH", pkgConfig: "libssh", providers: [.brew(["libssh"])]),
        .target(name: "Core", dependencies: ["CLibSSH"]),
        .testTarget(name: "CoreTests", dependencies: ["Core"]),
        .executableTarget(name: "SFTPPlayer", dependencies: ["CMPV", "Core"]),
        .executableTarget(name: "Spike", dependencies: ["CMPV", "Core"]),
    ]
)
