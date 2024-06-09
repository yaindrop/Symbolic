import Foundation

extension Dictionary {
    func value(key: Key) -> Value? { self[key] }

    mutating func getOrSetDefault(key: Key, _ defaultValue: @autoclosure () -> Value) -> Value {
        if let value = self[key] {
            return value
        }
        let value = defaultValue()
        self[key] = value
        return value
    }
}

extension Array {
    func shifted(by size: Int) -> [Element?] {
        guard size < count else { return .init(repeating: nil, count: count) }
        return suffix(count - size) + .init(repeating: nil, count: size)
    }

    func intersection(_ other: Self) -> Set<Element> where Element: Hashable {
        Set(self).intersection(other)
    }

    func subtracting(_ other: Self) -> Self where Element: Hashable {
        let intersection = self.intersection(other)
        return filter { intersection.contains($0) }
    }

    func allOrNone<T>() -> [T]? where Element == T? {
        guard allSatisfy({ $0 != nil }) else { return nil }
        return compactMap { $0 }
    }
}
