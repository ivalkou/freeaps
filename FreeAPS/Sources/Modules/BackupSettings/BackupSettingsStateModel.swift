import Combine
import Foundation
import SwiftUI

extension BackupSettings {
    final class StateModel: BaseStateModel<Provider> {
        @Published var dailyBackupEnabled = true
        @Published var backupHour = 12
        @Published var backupRetentionDays = 7
        @Published var backups: [URL] = []
        @Published var isCreatingBackup = false

        override func subscribe() {
            subscribeSetting(\.dailyBackupEnabled, on: $dailyBackupEnabled) { dailyBackupEnabled = $0 }
            subscribeSetting(\.backupHour, on: $backupHour) { backupHour = $0 }
            subscribeSetting(\.backupRetentionDays, on: $backupRetentionDays) { backupRetentionDays = $0 }

            refreshBackupList()
        }

        func refreshBackupList() {
            backups = provider.backupManager.listBackups()
        }

        func createBackupNow() {
            isCreatingBackup = true
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                _ = self?.provider.backupManager.createBackup()
                DispatchQueue.main.async {
                    self?.isCreatingBackup = false
                    self?.refreshBackupList()
                }
            }
        }

        func deleteBackup(at url: URL) {
            provider.backupManager.deleteBackup(at: url)
            refreshBackupList()
        }

        func shareBackup(at url: URL) -> URL {
            url
        }
    }
}
