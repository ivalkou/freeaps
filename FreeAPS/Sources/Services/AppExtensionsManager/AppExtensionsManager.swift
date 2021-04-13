import Foundation
import Swinject
import WidgetKit

protocol AppExtensionsManager {}

final class BaseAppExtensionsManager: AppExtensionsManager, Injectable {
    @Injected() var broadcaster: Broadcaster!

    init(resolver: Resolver) {
        injectServices(resolver)
    }

    private func subscribe() {}
}
