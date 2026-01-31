// swift-tools-version: 5.9
import PackageDescription

#if TUIST
    import ProjectDescription

    let packageSettings = PackageSettings(
        productTypes: [
            "Swinject": .framework,
            "SwiftDate": .framework,
            "Algorithms": .framework,
            "SwiftMessages": .framework,
            "LibreTransmitter": .framework
        ]
    )
#endif

let package = Package(
    name: "FreeAPS",
    dependencies: [
        .package(url: "https://github.com/Swinject/Swinject", from: "2.8.1"),
        .package(url: "https://github.com/malcommac/SwiftDate", from: "6.3.1"),
        .package(url: "https://github.com/apple/swift-algorithms", from: "1.0.0"),
        .package(url: "https://github.com/SwiftKickMobile/SwiftMessages", from: "9.0.5"),
        .package(path: "../Dependencies/LibreTransmitter")
    ]
)
