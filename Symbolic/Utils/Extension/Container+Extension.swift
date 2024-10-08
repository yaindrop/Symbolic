import Foundation

extension Dictionary {
    func get(_ key: Key) -> Value? { self[key] }

    mutating func get(_ key: Key, orSet defaultValue: @autoclosure () -> Value) -> Value {
        if let value = self[key] {
            return value
        }
        let value = defaultValue()
        self[key] = value
        return value
    }
}

extension Array {
    func value(at index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }

    func shifted(by size: Int) -> [Element?] {
        guard size < count else { return .init(repeating: nil, count: count) }
        return suffix(count - size) + .init(repeating: nil, count: size)
    }

    func completeMap<T>(_ transform: (Element) throws -> T?) rethrows -> [T]? {
        let mapped = try compactMap(transform)
        guard mapped.count == count else { return nil }
        return mapped
    }

    func compact<T>() -> [T] where Element == T? { compactMap { $0 }}

    func complete<T>() -> [T]? where Element == T? { completeMap { $0 } }

    func allSame() -> Element? where Element: Equatable {
        allSatisfy { $0 == first } ? first : nil
    }
}

extension Array where Element: Hashable {
    func toSet() -> Set<Element> { .init(self) }

    func intersection(_ other: Self) -> Set<Element> {
        Set(self).intersection(other)
    }

    func subtracting(_ other: Self) -> Self {
        let intersection = self.intersection(other)
        return filter { intersection.contains($0) }
    }
}
