import Combine
import Foundation
import Swinject
import ZIPFoundation

protocol BackupManager {
    func createBackup() -> URL?
    func listBackups() -> [URL]
    func deleteBackup(at url: URL)
    func applyRetentionPolicy()
}

final class BaseBackupManager: BackupManager, Injectable {
    private let processQueue = DispatchQueue(label: "BaseBackupManager.processQueue")
    @Injected() var settingsManager: SettingsManager!
    @Injected() var storage: FileStorage!

    private var lifetime = Lifetime()
    private let timer = DispatchTimer(timeInterval: 60) // Check every minute
    private var lastBackupDate: Date?

    private let filesToBackup = [
        OpenAPS.Settings.bgTargets,
        OpenAPS.Settings.settings,
        OpenAPS.Settings.profile,
        OpenAPS.Monitor.pumpHistory,
        OpenAPS.Monitor.iob,
        OpenAPS.Monitor.carbHistory,
        OpenAPS.Monitor.glucose
    ]

    private var backupsDirectory: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent("Backups", isDirectory: true)
    }

    init(resolver: Resolver) {
        injectServices(resolver)
        createBackupsDirectoryIfNeeded()
        subscribe()
    }

    private func createBackupsDirectoryIfNeeded() {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: backupsDirectory.path) {
            try? fileManager.createDirectory(at: backupsDirectory, withIntermediateDirectories: true)
        }
    }

    private func subscribe() {
        timer.publisher
            .receive(on: processQueue)
            .sink { [weak self] _ in
                self?.checkAndPerformBackup()
            }
            .store(in: &lifetime)
        timer.resume()
    }

    private func checkAndPerformBackup() {
        guard settingsManager.settings.dailyBackupEnabled else { return }

        let calendar = Calendar.current
        let now = Date()
        let currentHour = calendar.component(.hour, from: now)
        let backupHour = settingsManager.settings.backupHour

        // Check if we're in the backup hour
        guard currentHour >= backupHour else { return }

        // Check if we already have a backup for today
        let todayString = dateString(from: now)
        let todayBackupURL = backupsDirectory.appendingPathComponent("\(todayString).zip")

        if FileManager.default.fileExists(atPath: todayBackupURL.path) {
            return // Already backed up today
        }

        debug(.default, "BackupManager: Creating daily backup")
        _ = createBackup()
        applyRetentionPolicy()
    }

    func createBackup() -> URL? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())
        let zipURL = backupsDirectory.appendingPathComponent("\(dateString).zip")

        // Remove existing backup for today if exists
        if FileManager.default.fileExists(atPath: zipURL.path) {
            try? FileManager.default.removeItem(at: zipURL)
        }

        guard let archive = Archive(url: zipURL, accessMode: .create) else {
            debug(.default, "BackupManager: Failed to create archive at \(zipURL)")
            return nil
        }

        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

        for file in filesToBackup {
            let fileURL = documentsPath.appendingPathComponent(file)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                do {
                    try archive.addEntry(with: file, relativeTo: documentsPath)
                } catch {
                    debug(.default, "BackupManager: Failed to add \(file) to archive: \(error)")
                }
            }
        }

        debug(.default, "BackupManager: Backup created at \(zipURL)")
        return zipURL
    }

    func listBackups() -> [URL] {
        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(
            at: backupsDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return contents
            .filter { $0.pathExtension == "zip" }
            .sorted { url1, url2 in
                // Sort by filename (date) descending
                url1.lastPathComponent > url2.lastPathComponent
            }
    }

    func deleteBackup(at url: URL) {
        try? FileManager.default.removeItem(at: url)
        debug(.default, "BackupManager: Deleted backup at \(url)")
    }

    func applyRetentionPolicy() {
        let retentionDays = settingsManager.settings.backupRetentionDays
        let backups = listBackups()

        guard backups.count > retentionDays else { return }

        // Delete oldest backups beyond retention period
        let backupsToDelete = backups.dropFirst(retentionDays)
        for backup in backupsToDelete {
            deleteBackup(at: backup)
        }
    }

    private func dateString(from date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter.string(from: date)
    }
}
