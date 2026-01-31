enum BackupSettings {
    enum Config {}
}

protocol BackupSettingsProvider: Provider {
    var backupManager: BackupManager { get }
}
