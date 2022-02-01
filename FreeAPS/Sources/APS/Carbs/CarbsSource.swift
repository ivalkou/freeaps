import Combine

protocol CarbsSource: SourceInfoProvider {
    func fetchCarbs() -> AnyPublisher<[CarbsEntry], Never>
}
