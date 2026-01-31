import Foundation
import Swinject

extension BackupSettings {
    final class Provider: BaseProvider, BackupSettingsProvider {
        @Injected() private var _backupManager: BackupManager!

        var backupManager: BackupManager { _backupManager }
    }
}
