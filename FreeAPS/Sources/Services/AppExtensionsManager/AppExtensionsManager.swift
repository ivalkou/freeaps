import Foundation
import Swinject
import WidgetKit

protocol AppExtensionsManager {}

final class BaseAppExtensionsManager: AppExtensionsManager, Injectable {
    @Injected() var broadcaster: Broadcaster!

    init(resolver: Resolver) {
        injectServices(resolver)
        subscribe()
    }

    private func subscribe() {
        broadcaster.register(GlucoseObserver.self, observer: self)
    }

    private func setupGlucose(_ glucose: [BloodGlucose]) {
        let recentGlucose = glucose.last
        var glucoseDelta: Int?
        if glucose.count >= 2 {
            glucoseDelta = (recentGlucose?.glucose ?? 0) - (glucose[glucose.count - 2].glucose ?? 0)
        } else {
            glucoseDelta = nil
        }

        UserDefaults.appGroup?.setValue(recentGlucose, forKey: "RecentGlucose")
        UserDefaults.appGroup?.setValue(glucoseDelta, forKey: "GlucoseDelta")
        UserDefaults.appGroup?.synchronize()
        WidgetCenter.shared.reloadAllTimelines()
    }
}

extension BaseAppExtensionsManager: GlucoseObserver {
    func glucoseDidUpdate(_ glucose: [BloodGlucose]) {
        setupGlucose(glucose)
    }
}
