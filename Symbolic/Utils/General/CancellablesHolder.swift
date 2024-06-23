import Combine

// MARK: - CancellablesHolder

protocol CancellablesHolder: AnyObject {
    var cancellables: Set<AnyCancellable> { get set }
}

extension CancellablesHolder {
    func cancelAll() { cancellables.removeAll() }
    func holdCancellables(@CancellablesBuilder _ builder: () -> Set<AnyCancellable>) { cancellables = builder() }
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
