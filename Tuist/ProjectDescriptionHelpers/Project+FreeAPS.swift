import ProjectDescription

// MARK: - Project Configuration

public enum FreeAPSConfig {
    public static let appName = "FreeAPS X"
    public static let bundleIdPrefix = "ru.artpancreas"
    public static let appGroupIdSuffix = "loopkit.LoopGroup"
    public static let buildVersion = "0.2.6"
    public static let marketingVersion = "3.2.0"

    // Read from .env via Environment
    // TUIST_DEVELOPER_TEAM is accessed via Environment.developerTeam
    public static var developerTeam: String {
        Environment.developerTeam.getString(default: "MISSING_TEAM_ID")
    }

    // Computed bundle identifiers
    public static var bundleId: String {
        "\(bundleIdPrefix).\(developerTeam).FreeAPS"
    }

    public static var watchBundleId: String {
        "\(bundleId).watchkitapp"
    }

    public static var watchExtensionBundleId: String {
        "\(watchBundleId).watchkitextension"
    }

    public static var appGroupId: String {
        "group.com.\(appGroupIdSuffix)"
    }
}

// MARK: - Deployment Targets

public extension DeploymentTargets {
    static let iOS = DeploymentTargets.iOS("18.0")
    static let watchOS = DeploymentTargets.watchOS("11.0")
}

// MARK: - Settings Helpers

public extension SettingsDictionary {
    static func freeAPSBase(
        bundleId: String,
        teamId: String = FreeAPSConfig.developerTeam
    ) -> SettingsDictionary {
        [
            "DEVELOPMENT_TEAM": .string(teamId),
            "CODE_SIGN_STYLE": "Automatic",
            "PRODUCT_BUNDLE_IDENTIFIER": .string(bundleId),
            "MARKETING_VERSION": .string(FreeAPSConfig.marketingVersion),
            "CURRENT_PROJECT_VERSION": .string(FreeAPSConfig.buildVersion),
            "BUILD_VERSION": .string(FreeAPSConfig.buildVersion),
            "APP_DISPLAY_NAME": .string(FreeAPSConfig.appName),
            "APP_GROUP_ID": .string(FreeAPSConfig.appGroupId),
            "BUNDLE_IDENTIFIER": .string(FreeAPSConfig.bundleId)
        ]
    }

    static func iOSFrameworkSearchPaths() -> SettingsDictionary {
        [
            "FRAMEWORK_SEARCH_PATHS": .array([
                "$(inherited)",
                "$(BUILT_PRODUCTS_DIR)"
            ])
        ]
    }
}

// MARK: - InfoPlist Helpers

public extension InfoPlist {
    static func freeAPSMain() -> InfoPlist {
        .extendingDefault(with: [
            "AppGroupID": .string("$(APP_GROUP_ID)"),
            "CFBundleDisplayName": .string("$(APP_DISPLAY_NAME)"),
            "CFBundleName": .string("$(APP_DISPLAY_NAME)"),
            "CFBundleShortVersionString": .string("$(MARKETING_VERSION)"),
            "CFBundleVersion": .string("$(BUILD_VERSION)"),
            "CFBundleURLTypes": .array([
                .dictionary([
                    "CFBundleTypeRole": .string("Editor"),
                    "CFBundleURLSchemes": .array([.string("freeaps-x")])
                ])
            ]),
            "ITSAppUsesNonExemptEncryption": .boolean(false),
            "LSApplicationQueriesSchemes": .array([
                .string("gcm-ciq"),
                .string("xdripswift"),
                .string("dexcomg6"),
                .string("dexcomcgm"),
                .string("diabox"),
                .string("spikeapp"),
                .string("libredirect")
            ]),
            "LSRequiresIPhoneOS": .boolean(true),
            "LSSupportsOpeningDocumentsInPlace": .boolean(true),
            "NFCReaderUsageDescription": .string("NFC is used to scan Libre sensors."),
            "NSAppTransportSecurity": .dictionary([
                "NSAllowsArbitraryLoads": .boolean(true)
            ]),
            "NSBluetoothAlwaysUsageDescription": .string(
                "Bluetooth is used to communicate with insulin pump and continuous glucose monitor devices"
            ),
            "NSBluetoothPeripheralUsageDescription": .string(
                "Bluetooth is used to communicate with insulin pump and continuous glucose monitor devices"
            ),
            "NSCalendarsUsageDescription": .string("Calendar is used to create a new glucose events."),
            "NSFaceIDUsageDescription": .string("For authorized acces to bolus"),
            "NSHealthShareUsageDescription": .string("Health App is used to store blood glucose data"),
            "NSHealthUpdateUsageDescription": .string("Health App is used to store blood glucose data"),
            "UIApplicationSceneManifest": .dictionary([
                "UIApplicationSupportsMultipleScenes": .boolean(false)
            ]),
            "UIApplicationSupportsIndirectInputEvents": .boolean(true),
            "UIBackgroundModes": .array([
                .string("bluetooth-central"),
                .string("bluetooth-peripheral")
            ]),
            "UIFileSharingEnabled": .boolean(true),
            "UILaunchScreen": .dictionary([:]),
            "UIRequiredDeviceCapabilities": .array([.string("armv7")]),
            "UIRequiresFullScreen": .boolean(false),
            "UISupportedInterfaceOrientations": .array([
                .string("UIInterfaceOrientationPortrait"),
                .string("UIInterfaceOrientationPortraitUpsideDown")
            ]),
            "UISupportedInterfaceOrientations~ipad": .array([
                .string("UIInterfaceOrientationPortrait"),
                .string("UIInterfaceOrientationPortraitUpsideDown"),
                .string("UIInterfaceOrientationLandscapeLeft"),
                .string("UIInterfaceOrientationLandscapeRight")
            ])
        ])
    }

    static func watchExtension() -> InfoPlist {
        .extendingDefault(with: [
            "NSExtension": .dictionary([
                "NSExtensionAttributes": .dictionary([
                    "WKAppBundleIdentifier": .string("$(BUNDLE_IDENTIFIER).watchkitapp")
                ]),
                "NSExtensionPointIdentifier": .string("com.apple.watchkit")
            ])
        ])
    }
}
