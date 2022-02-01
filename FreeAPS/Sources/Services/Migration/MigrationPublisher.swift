import Combine
import Foundation
import SwiftUI

/**

 Example of using DataMigrationTool

 Publishers
     .dataMigrationTool(AppTargetInfo())
     .migrate { info in
        // ...
     }
     .sink {
        // ...
     }

 info is AppTargetInfo instance, which contains target information (version and etc).

 */

extension Publishers {
    static func getMigrationPublisher(_ appInfo: TargetInformation) -> MigrationPublisher {
        MigrationPublisher(appInfo)
    }

    class MigrationSubscription<S: Subscriber>: Subscription where S.Input == TargetInformation, S.Failure == Never {
        private var targetInformation: TargetInformation
        private var subscriber: S?

        init(_ appInfo: TargetInformation, subscriber: S) {
            targetInformation = appInfo
            self.subscriber = subscriber
        }

        func cancel() {
            subscriber = nil
        }

        func request(_: Subscribers.Demand) {
            _ = subscriber?.receive(targetInformation)
            subscriber?.receive(completion: .finished)
            return
        }
    }

    struct MigrationPublisher: Publisher {
        typealias Output = TargetInformation
        typealias Failure = Never

        @State private var targetInformation: TargetInformation

        init(_ AppTargetInfo: TargetInformation) {
            targetInformation = AppTargetInfo
        }

        func receive<S>(subscriber: S) where S: Subscriber, Never == S.Failure, TargetInformation == S.Input {
            let subscription = MigrationSubscription(targetInformation, subscriber: subscriber)
            subscriber.receive(subscription: subscription)
        }

        func migrate(_ handler: (TargetInformation) -> Void) -> Self {
            handler(targetInformation)
            return self
        }

        func actualLastMigrationVersion() -> Self {
            targetInformation.actualLastMigrationVersion()
            return self
        }
    }
}
