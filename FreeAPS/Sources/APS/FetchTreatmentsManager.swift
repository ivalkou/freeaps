import Combine
import Foundation
import SwiftDate
import Swinject

protocol FetchTreatmentsManager {}

final class BaseFetchTreatmentsManager: FetchTreatmentsManager, Injectable {
    private let processQueue = DispatchQueue(label: "BaseFetchTreatmentsManager.processQueue")
    @Injected() var nightscoutManager: NightscoutManager!
    @Injected() var tempTargetsStorage: TempTargetsStorage!
    @Injected() var carbsStorage: CarbsStorage!
    @Injected() var healthKitManager: HealthKitManager!

    private var lifetime = Lifetime()
    private let timer = DispatchTimer(timeInterval: 1.minutes.timeInterval)

    init(resolver: Resolver) {
        injectServices(resolver)
        subscribe()
    }

    private func subscribe() {
        timer.publisher
            .receive(on: processQueue)
            .flatMap { _ -> AnyPublisher<([CarbsEntry], [TempTarget], [CarbsEntry]), Never> in
                debug(.nightscout, "FetchTreatmentsManager heartbeat")
                debug(.nightscout, "Start fetching carbs and temptargets")
                return Publishers.CombineLatest3(
                    self.nightscoutManager.fetchCarbs(),
                    self.nightscoutManager.fetchTempTargets(),
                    self.healthKitManager.fetchCarbs()
                ).eraseToAnyPublisher()
            }
            .sink { carbs, targets, carbsFromHealth in
                let allCarbs = carbs + carbsFromHealth
                let since = self.carbsStorage.syncDate()
                let filteredCarbs = allCarbs.filter { $0.createdAt > since }
                let carbsForHealth = allCarbs.filter { !carbsFromHealth.contains($0) }

                if filteredCarbs.isNotEmpty {
                    self.carbsStorage.storeCarbs(filteredCarbs)
                }
                if carbsForHealth.isNotEmpty {
                    self.healthKitManager.saveIfNeeded(carbs: filteredCarbs)
                }
                let filteredTargets = targets.filter { !($0.enteredBy?.contains(TempTarget.manual) ?? false) }
                if filteredTargets.isNotEmpty {
                    self.tempTargetsStorage.storeTempTargets(filteredTargets)
                }
            }
            .store(in: &lifetime)
        timer.fire()
        timer.resume()
    }
}
