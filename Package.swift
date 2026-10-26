// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SftpMediaPlayerNative",
    platforms: [.macOS(.v14)],
    targets: [
        .systemLibrary(name: "CMPV", pkgConfig: "mpv", providers: [.brew(["mpv"])]),
        .systemLibrary(name: "CLibSSH", pkgConfig: "libssh", providers: [.brew(["libssh"])]),
        .executableTarget(name: "Spike", dependencies: ["CMPV", "CLibSSH"]),
    ]
)
