// swift-tools-version:6.0
import PackageDescription

extension [Platform] {
    static let darwin: [Platform] = [.macOS, .macCatalyst, .iOS, .tvOS, .watchOS, .visionOS]
    static let nonWasm: [Platform] = [.linux, .windows, .android, .openbsd]
    static let nonDarwin: [Platform] = nonWasm + [.wasi]
}

let package = Package(
    name: "AMSMB2",
    platforms: [
        .iOS(.v14),
        .macOS(.v11),
        .macCatalyst(.v14),
        .tvOS(.v14),
        .watchOS(.v7),
        .visionOS(.v1),
    ],
    products: [
        .library(
            name: "AMSMB2",
            type: .dynamic,
            targets: ["AMSMB2"]
        ),
    ],
    targets: [
        .target(
            name: "libsmb2",
            path: "Dependencies/libsmb2",
            exclude: [
                "lib/CMakeLists.txt",
                "lib/libsmb2.syms",
                "lib/Makefile.am",
                "lib/Makefile.AMIGA",
                "lib/Makefile.AMIGA_AROS",
                "lib/Makefile.AMIGA_OS3",
                "lib/Makefile.PS3_PPU",
                "lib/ps2",
            ],
            sources: [
                "lib",
            ],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include"),
                .headerSearchPath("include/apple"),
                .headerSearchPath("include/smb2"),
                .headerSearchPath("lib"),
                .define("_U_", to: "__attribute__((unused))"),
                .define("HAVE_CONFIG_H", to: "1"),
            ],
            linkerSettings: [
            ]
        ),
        .target(
            name: "AMSMB2",
            dependencies: [
                "libsmb2",
            ],
            path: "AMSMB2"
        ),
    ]
)

for target in package.targets {
    let swiftSettings: [SwiftSetting] = [
        .enableUpcomingFeature("ExistentialAny"),
    ]
    target.swiftSettings = swiftSettings
}
