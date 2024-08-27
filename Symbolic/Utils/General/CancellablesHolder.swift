import Combine

// MARK: - CancellablesHolder

protocol CancellablesHolder {
    var cancellables: Set<AnyCancellable> { get nonmutating set }
}

extension CancellablesHolder {
    func cancelAll() { cancellables.removeAll() }
    func holdCancellables(@CancellablesBuilder _ builder: () -> Set<AnyCancellable>) { cancellables = builder() }
    func holdCancellables(@CancellablesBuilder _ builder: (Self) -> Set<AnyCancellable>) { cancellables = builder(self) }
}

extension AnyCancellable {
    func store(in holder: CancellablesHolder) {
        store(in: &holder.cancellables)
    }
}

// MARK: - CancellablesBuilder

@resultBuilder
struct CancellablesBuilder {
    static func buildBlock(_ parts: AnyCancellable...) -> Set<AnyCancellable> { Set(parts) }
}
