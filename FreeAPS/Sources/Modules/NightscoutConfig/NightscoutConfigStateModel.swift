import Combine
import SwiftDate
import SwiftUI

extension NightscoutConfig {
    final class StateModel: BaseStateModel<Provider> {
        @Injected() private var keychain: Keychain!
        @Injected() private var nightscoutManager: NightscoutManager!
        @Injected() private var glucoseStorage: GlucoseStorage!

        @Published var url = ""
        @Published var secret = ""
        @Published var message = ""
        @Published var connecting = false
        @Published var backfilling = false
        @Published var isUploadEnabled = false

        @Published var useLocalSource = false
        @Published var localPort: Decimal = 0

        override func subscribe() {
            url = keychain.getValue(String.self, forKey: Config.urlKey) ?? ""
            secret = keychain.getValue(String.self, forKey: Config.secretKey) ?? ""

            subscribeSetting(\.isUploadEnabled, on: $isUploadEnabled) { isUploadEnabled = $0 }
            subscribeSetting(\.useLocalGlucoseSource, on: $useLocalSource) { useLocalSource = $0 }
            subscribeSetting(\.localGlucosePort, on: $localPort.map(Int.init)) { localPort = Decimal($0) }
        }

        func connect() {
            guard let url = URL(string: url) else {
                message = "Invalid URL"
                return
            }
            connecting = true
            message = ""
            provider.checkConnection(url: url, secret: secret.isEmpty ? nil : secret)
                .receive(on: DispatchQueue.main)
                .sink { completion in
                    switch completion {
                    case .finished: break
                    case let .failure(error):
                        self.message = "Error: \(error.localizedDescription)"
                    }
                    self.connecting = false
                } receiveValue: {
                    self.message = "Connected!"
                    self.keychain.setValue(self.url, forKey: Config.urlKey)
                    self.keychain.setValue(self.secret, forKey: Config.secretKey)
                }
                .store(in: &lifetime)
        }

        func backfillGlucose() {
            backfilling = true
            nightscoutManager.fetchGlucose(since: Date().addingTimeInterval(-1.days.timeInterval))
                .sink { [weak self] glucose in
                    guard let self = self else { return }
                    DispatchQueue.main.async {
                        self.backfilling = false
                    }

                    guard glucose.isNotEmpty else { return }
                    self.glucoseStorage.storeGlucose(glucose)
                }
                .store(in: &lifetime)
        }

        func delete() {
            keychain.removeObject(forKey: Config.urlKey)
            keychain.removeObject(forKey: Config.secretKey)
            url = ""
            secret = ""
        }
    }
}
