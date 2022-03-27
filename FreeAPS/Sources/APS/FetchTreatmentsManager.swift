import Combine
import Foundation
import SwiftDate
import Swinject

protocol FetchTreatmentsManager {}

final class BaseFetchTreatmentsManager: FetchTreatmentsManager, Injectable {
    private let processQueue = DispatchQueue(label: "BaseFetchTreatmentsManager.processQueue")
    @Injected() var nightscoutManager: NightscoutManager!
    @Injected() var healthKitManager: HealthKitManager!
    @Injected() var tempTargetsStorage: TempTargetsStorage!
    @Injected() var carbsStorage: CarbsStorage!

    private var lifetime = Lifetime()
    private let timer = DispatchTimer(timeInterval: 1.minutes.timeInterval)

    init(resolver: Resolver) {
        injectServices(resolver)
        subscribe()
    }

    private func subscribe() {
        timer.publisher
            .receive(on: processQueue)
            .flatMap { _ -> AnyPublisher<([CarbsEntry], [CarbsEntry], [TempTarget]), Never> in
                debug(.nightscout, "FetchTreatmentsManager heartbeat")
                debug(.nightscout, "Start fetching carbs and temptargets")
                return Publishers.CombineLatest3(
                    self.nightscoutManager.fetchCarbs(),
                    self.healthKitManager.fetchCarbs(),
                    self.nightscoutManager.fetchTempTargets()
                ).eraseToAnyPublisher()
            }
            .sink { carbsFromNS, carbsFromAH, targets in
                let carbs = carbsFromAH + carbsFromNS
                let filteredCarbs = carbs.filter { !($0.enteredBy?.contains(CarbsEntry.manual) ?? false) }
                if filteredCarbs.isNotEmpty {
                    self.carbsStorage.storeCarbs(filteredCarbs)
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
