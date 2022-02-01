import Combine
import SwiftUI
import Swinject

@main struct FreeAPSApp: App {
    @Environment(\.scenePhase) var scenePhase
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var isMigrating: Bool = true

    // Migration
    private var migrationManager = MigrationManager()
    @State private var lifetime: Lifetime = []

    // Dependencies Assembler
    // contain all dependencies Assemblies
    // TODO: Remove static key after update "Use Dependencies" logic
    private static var assembler = Assembler([
        StorageAssembly(),
        ServiceAssembly(),
        APSAssembly(),
        NetworkAssembly(),
        UIAssembly(),
        SecurityAssembly()
    ], parent: nil, defaultObjectScope: .container)

    var resolver: Resolver {
        FreeAPSApp.assembler.resolver
    }

    // Temp static var
    // Use to backward compatibility with old Dependencies logic on Logger
    // TODO: Remove var after update "Use Dependencies" logic in Logger
    static var resolver: Resolver {
        FreeAPSApp.assembler.resolver
    }

    private func loadServices() {
        resolver.resolve(AppearanceManager.self)!.setupGlobalAppearance()
        _ = resolver.resolve(DeviceDataManager.self)!
        _ = resolver.resolve(APSManager.self)!
        _ = resolver.resolve(FetchGlucoseManager.self)!
        _ = resolver.resolve(FetchTreatmentsManager.self)!
        _ = resolver.resolve(FetchAnnouncementsManager.self)!
        _ = resolver.resolve(CalendarManager.self)!
        _ = resolver.resolve(UserNotificationsManager.self)!
        _ = resolver.resolve(WatchManager.self)!
        _ = resolver.resolve(HealthKitManager.self)!
    }

    init() {
        loadServices()
        _isMigrating = State(initialValue: migrationManager.isNeedMigrate)
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if isMigrating {
                    Migration.RootView(resolver: resolver)
                        .onAppear { runMigration() }
                } else {
                    Main.RootView(resolver: resolver)
                }
            }
            .animation(.easeIn(duration: 0.75), value: self.isMigrating)
        }
        .onChange(of: scenePhase) { newScenePhase in
            debug(.default, "APPLICATION PHASE: \(newScenePhase)")
        }
    }

    private func runMigration() {
        migrationManager
            .publisher
            .sink { [self] _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    isMigrating = false
                }
            }
            .store(in: &lifetime)
    }
}
