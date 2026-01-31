import SwiftUI
import Swinject

extension BackupSettings {
    struct RootView: BaseView {
        let resolver: Resolver
        @StateObject var state = StateModel()
        @State private var shareURL: URL?
        @State private var showShareSheet = false

        private var hourOptions: [Int] {
            Array(0 ... 23)
        }

        var body: some View {
            Form {
                Section(header: Text("Automatic Backup")) {
                    Toggle("Enable Daily Backup", isOn: $state.dailyBackupEnabled)

                    if state.dailyBackupEnabled {
                        Picker("Backup Time", selection: $state.backupHour) {
                            ForEach(hourOptions, id: \.self) { hour in
                                Text(formatHour(hour)).tag(hour)
                            }
                        }

                        Stepper(
                            "Retention: \(state.backupRetentionDays) days",
                            value: $state.backupRetentionDays,
                            in: 1 ... 30
                        )
                    }
                }

                Section(header: Text("Manual Backup")) {
                    Button(action: {
                        state.createBackupNow()
                    }) {
                        HStack {
                            Text("Create Backup Now")
                            Spacer()
                            if state.isCreatingBackup {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(state.isCreatingBackup)
                }

                if !state.backups.isEmpty {
                    Section(header: Text("Existing Backups")) {
                        ForEach(state.backups, id: \.absoluteString) { backup in
                            HStack {
                                Text(backupDisplayName(backup))
                                Spacer()
                                Button(action: {
                                    shareURL = backup
                                    showShareSheet = true
                                }) {
                                    Image(systemName: "square.and.arrow.up")
                                }
                                .buttonStyle(BorderlessButtonStyle())
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    state.deleteBackup(at: backup)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .onAppear(perform: configureView)
            .navigationBarTitle("Backup")
            .navigationBarTitleDisplayMode(.automatic)
            .sheet(isPresented: $showShareSheet) {
                if let url = shareURL {
                    ShareSheet(activityItems: [url])
                }
            }
        }

        private func formatHour(_ hour: Int) -> String {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            let date = Calendar.current.date(from: DateComponents(hour: hour, minute: 0))!
            return formatter.string(from: date)
        }

        private func backupDisplayName(_ url: URL) -> String {
            let filename = url.deletingPathExtension().lastPathComponent
            // Convert YYYY-MM-DD to more readable format
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            if let date = dateFormatter.date(from: filename) {
                dateFormatter.dateStyle = .medium
                dateFormatter.timeStyle = .none
                return dateFormatter.string(from: date)
            }
            return filename
        }
    }
}
