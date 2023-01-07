import Foundation
import Swinject

final class StorageAssembly: Assembly {
    func assemble(container: Container) {
        container.register(FileManager.self) { _ in
            Foundation.FileManager.default
        }
        container.register(FileStorage.self) { _ in BaseFileStorage() }
        container.register(PumpHistoryStorage.self) { r in BasePumpHistoryStorage(resolver: r) }
        container.register(GlucoseStorage.self) { r in BaseGlucoseStorage(resolver: r) }
        container.register(TempTargetsStorage.self) { r in BaseTempTargetsStorage(resolver: r) }
        container.register(CarbsStorage.self) { r in BaseCarbsStorage(resolver: r) }
        container.register(AnnouncementsStorage.self) { r in BaseAnnouncementsStorage(resolver: r) }
        container.register(SettingsManager.self) { r in BaseSettingsManager(resolver: r) }
        container.register(Keychain.self) { _ in BaseKeychain() }
        container.register(AlertHistoryStorage.self) { r in BaseAlertHistoryStorage(resolver: r) }
    }
}
