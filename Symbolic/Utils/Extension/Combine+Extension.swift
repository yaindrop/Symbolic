import Combine

extension Publisher {
    func eraseToVoidPublisher() -> AnyPublisher<Void, Failure> {
        map { _ in () }.eraseToAnyPublisher()
    }
}
