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

        func migrate(startAtVersion version: String, _ workItem: MigrationWorkItem) -> Self {
            manager.migrate(startAtVersion: version, workItem)
            return self
        }
    }
}
