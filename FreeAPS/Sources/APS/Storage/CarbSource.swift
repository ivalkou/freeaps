import Combine

protocol CarbSource {
    func fetchCarbs() -> AnyPublisher<[CarbsEntry], Never>
}
