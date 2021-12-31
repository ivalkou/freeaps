import Combine

protocol CarbSource {
    func fetch() -> AnyPublisher<[CarbsEntry], Never>
}
