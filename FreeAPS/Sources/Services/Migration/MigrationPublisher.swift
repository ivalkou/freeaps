import Combine
import Foundation
import SwiftUI

extension Publishers {
    static func getMigrationPublisher(fromMigrationManager manager: MigrationManager) -> MigrationPublisher {
        MigrationPublisher(manager)
    }

    class MigrationSubscription<S: Subscriber>: Subscription where S.Input == AppInfo, S.Failure == Never {
        private var manager: MigrationManager
        private var subscriber: S?

        init(_ manager: MigrationManager, subscriber: S) {
            self.manager = manager
            self.subscriber = subscriber
        }

        func cancel() {
            subscriber = nil
        }

        func request(_: Subscribers.Demand) {
            _ = subscriber?.receive(manager.appInfo)
            subscriber?.receive(completion: .finished)
            return
        }
    }

    struct MigrationPublisher: Publisher {
        typealias Output = AppInfo
        typealias Failure = Never

        private var manager: MigrationManager

        init(_ manager: MigrationManager) {
            self.manager = manager
        }

        func receive<S>(subscriber: S) where S: Subscriber, Never == S.Failure, AppInfo == S.Input {
            let subscription = MigrationSubscription(manager, subscriber: subscriber)
            subscriber.receive(subscription: subscription)
        }

        func tryAsyncMigrate(onVersion version: String, _ handler: @escaping (AppInfo) async throws -> Void) throws -> Self {
            Task {
                if manager.checkMigrationNeeded(onVersion: version) {
                    try await handler(manager.appInfo)
                }
            }
            return self
        }

        func migrate(onVersion version: String, _ handler: (AppInfo) -> Void) -> Self {
            debug(.businessLogic, "Try to execute migration on version \(version)")
            if manager.checkMigrationNeeded(onVersion: version) {
                debug(.businessLogic, "Migration will start")
                handler(manager.appInfo)
            } else {
                debug(.businessLogic, "Migration skipped")
            }
            return self
        }

        // TODO: Add tryMigrate
        // TODO: Add asyncMigrate

        func updateLastAppMigrationVersionToCurrent() -> Self {
            manager.setActualLastMigrationAppVersion()
            return self
        }
    }
}
