import ProjectDescription
import ProjectDescriptionHelpers

// MARK: - Project

let project = Project(
    name: "FreeAPS",
    organizationName: "Ivan Valkou",
    settings: .settings(
        base: [
            "DEVELOPMENT_TEAM": .string(FreeAPSConfig.developerTeam)
        ],
        configurations: [
            .debug(name: "Debug"),
            .release(name: "Release")
        ]
    ),
    targets: [
        // MARK: - FreeAPS X (Main iOS App)

        .target(
            name: "FreeAPS X",
            destinations: .iOS,
            product: .app,
            bundleId: FreeAPSConfig.bundleId,
            deploymentTargets: .iOS("18.0"),
            infoPlist: .file(path: "FreeAPS/Resources/Info.plist"),
            sources: ["FreeAPS/Sources/**"],
            resources: [
                "FreeAPS/Resources/Assets.xcassets",
                "FreeAPS/Resources/*.lproj/**",
                .folderReference(path: "FreeAPS/Resources/javascript"),
                .folderReference(path: "FreeAPS/Resources/json")
            ],
            entitlements: .file(path: "FreeAPS/Resources/FreeAPS.entitlements"),
            scripts: [
                .pre(
                    script: """
                    if [ -f "${SRCROOT}/scripts/swiftformat.sh" ]; then
                        source "${SRCROOT}/scripts/swiftformat.sh"
                    fi
                    """,
                    name: "SwiftFormat",
                    basedOnDependencyAnalysis: false
                ),
                .post(
                    script: """
                    # Embed ConnectIQ framework for device builds only
                    if [ "$PLATFORM_NAME" = "iphoneos" ]; then
                        CONNECTIQ_SOURCE="${SRCROOT}/Dependencies/connectiq-mobile-sdk-ios-1.4/ConnectIQ.xcframework/ios-armv7_arm64/ConnectIQ.framework"
                        CONNECTIQ_DEST="${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}"

                        if [ -d "$CONNECTIQ_SOURCE" ]; then
                            mkdir -p "$CONNECTIQ_DEST"
                            cp -R "$CONNECTIQ_SOURCE" "$CONNECTIQ_DEST/"

                            # Sign the framework
                            if [ -n "$EXPANDED_CODE_SIGN_IDENTITY" ]; then
                                codesign --force --sign "$EXPANDED_CODE_SIGN_IDENTITY" "$CONNECTIQ_DEST/ConnectIQ.framework"
                            fi
                        fi
                    fi
                    """,
                    name: "Embed ConnectIQ",
                    basedOnDependencyAnalysis: false
                )
            ],
            dependencies: [
                // SPM dependencies
                .external(name: "Swinject"),
                .external(name: "SwiftDate"),
                .external(name: "Algorithms"),
                .external(name: "SwiftMessages"),
                .external(name: "LibreTransmitter"),
                .external(name: "ZIPFoundation"),

                // Pre-built XCFrameworks (built from Dependencies/)
                // Run scripts/build-dependencies.sh to build these
                .xcframework(path: "Frameworks/LoopKit.xcframework"),
                .xcframework(path: "Frameworks/LoopKitUI.xcframework"),
                .xcframework(path: "Frameworks/LoopTestingKit.xcframework"),
                .xcframework(path: "Frameworks/MockKit.xcframework"),
                .xcframework(path: "Frameworks/MockKitUI.xcframework"),
                .xcframework(path: "Frameworks/RileyLinkBLEKit.xcframework"),
                .xcframework(path: "Frameworks/RileyLinkKit.xcframework"),
                .xcframework(path: "Frameworks/RileyLinkKitUI.xcframework"),
                .xcframework(path: "Frameworks/MinimedKit.xcframework"),
                .xcframework(path: "Frameworks/MinimedKitUI.xcframework"),
                .xcframework(path: "Frameworks/OmniKit.xcframework"),
                .xcframework(path: "Frameworks/OmniKitUI.xcframework"),
                .xcframework(path: "Frameworks/Crypto.xcframework"),
                .xcframework(path: "Frameworks/CGMBLEKit.xcframework"),

                // ConnectIQ framework - linked only for device builds via OTHER_LDFLAGS
                // (doesn't support arm64 simulator)

                // System frameworks
                .sdk(name: "CoreNFC", type: .framework, status: .optional),
                .sdk(name: "HealthKit", type: .framework)
            ],
            settings: .settings(
                base: SettingsDictionary
                    .freeAPSBase(bundleId: FreeAPSConfig.bundleId)
                    .merging([
                        "INFOPLIST_FILE": .string("FreeAPS/Resources/Info.plist"),
                        "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
                        "ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES": "YES",
                        "SWIFT_VERSION": "5.0",
                        "PRODUCT_MODULE_NAME": "FreeAPS",
                        "FRAMEWORK_SEARCH_PATHS": .array([
                            "$(inherited)",
                            "$(BUILT_PRODUCTS_DIR)"
                        ]),
                        // ConnectIQ - link only for device (no arm64 simulator support)
                        "FRAMEWORK_SEARCH_PATHS[sdk=iphoneos*]": .array([
                            "$(inherited)",
                            "$(SRCROOT)/Dependencies/connectiq-mobile-sdk-ios-1.4/ConnectIQ.xcframework/ios-armv7_arm64"
                        ]),
                        "OTHER_LDFLAGS[sdk=iphoneos*]": .array([
                            "$(inherited)",
                            "-framework",
                            "ConnectIQ"
                        ])
                    ])
            )
        ),

        // MARK: - FreeAPSWatch (watchOS App)

        .target(
            name: "FreeAPSWatch",
            destinations: [.appleWatch],
            product: .watch2App,
            bundleId: FreeAPSConfig.watchBundleId,
            deploymentTargets: .watchOS("11.0"),
            infoPlist: .default,
            resources: [
                "FreeAPSWatch/Assets.xcassets"
            ],
            entitlements: .file(path: "FreeAPSWatch/FreeAPSWatch.entitlements"),
            dependencies: [
                .target(name: "FreeAPSWatch WatchKit Extension")
            ],
            settings: .settings(
                base: SettingsDictionary
                    .freeAPSBase(bundleId: FreeAPSConfig.watchBundleId)
                    .merging([
                        "WATCHOS_DEPLOYMENT_TARGET": "11.0",
                        "GENERATE_INFOPLIST_FILE": "YES",
                        "SKIP_INSTALL": "YES"
                    ])
            )
        ),

        // MARK: - FreeAPSWatch WatchKit Extension

        .target(
            name: "FreeAPSWatch WatchKit Extension",
            destinations: [.appleWatch],
            product: .watch2Extension,
            bundleId: FreeAPSConfig.watchExtensionBundleId,
            deploymentTargets: .watchOS("11.0"),
            infoPlist: .watchExtension(),
            sources: ["FreeAPSWatch WatchKit Extension/**/*.swift"],
            resources: [
                "FreeAPSWatch WatchKit Extension/Assets.xcassets",
                "FreeAPSWatch WatchKit Extension/Preview Content/**",
                "FreeAPSWatch WatchKit Extension/PushNotificationPayload.apns"
            ],
            entitlements: .file(path: "FreeAPSWatch WatchKit Extension/FreeAPSWatch WatchKit Extension.entitlements"),
            settings: .settings(
                base: SettingsDictionary
                    .freeAPSBase(bundleId: FreeAPSConfig.watchExtensionBundleId)
                    .merging([
                        "WATCHOS_DEPLOYMENT_TARGET": "11.0",
                        "GENERATE_INFOPLIST_FILE": "YES",
                        "INFOPLIST_FILE": .string("FreeAPSWatch WatchKit Extension/Info.plist"),
                        "SKIP_INSTALL": "YES",
                        "LD_RUNPATH_SEARCH_PATHS": .array([
                            "$(inherited)",
                            "@executable_path/Frameworks",
                            "@executable_path/../../Frameworks"
                        ])
                    ])
            )
        ),

        // MARK: - FreeAPSTests

        .target(
            name: "FreeAPSTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "ru.artpancreas.FreeAPSTests",
            deploymentTargets: .iOS("18.0"),
            infoPlist: .default,
            sources: ["FreeAPSTests/**"],
            dependencies: [
                .target(name: "FreeAPS X")
            ],
            settings: .settings(
                base: [
                    "DEVELOPMENT_TEAM": .string(FreeAPSConfig.developerTeam),
                    "CODE_SIGN_STYLE": "Automatic",
                    "BUNDLE_LOADER": "$(TEST_HOST)",
                    "TEST_HOST": "$(BUILT_PRODUCTS_DIR)/FreeAPS X.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/FreeAPS X"
                ]
            )
        )
    ],
    schemes: [
        .scheme(
            name: "FreeAPS X",
            shared: true,
            buildAction: .buildAction(
                targets: ["FreeAPS X"],
                preActions: []
            ),
            testAction: .targets(
                ["FreeAPSTests"],
                configuration: .debug,
                options: .options(coverage: true)
            ),
            runAction: .runAction(
                configuration: .debug,
                executable: "FreeAPS X"
            ),
            archiveAction: .archiveAction(configuration: .release),
            profileAction: .profileAction(
                configuration: .release,
                executable: "FreeAPS X"
            ),
            analyzeAction: .analyzeAction(configuration: .debug)
        ),
        .scheme(
            name: "FreeAPSWatch",
            shared: true,
            buildAction: .buildAction(
                targets: ["FreeAPSWatch", "FreeAPSWatch WatchKit Extension"]
            ),
            runAction: .runAction(
                configuration: .debug,
                executable: "FreeAPSWatch"
            ),
            archiveAction: .archiveAction(configuration: .release)
        )
    ],
    resourceSynthesizers: []
)
