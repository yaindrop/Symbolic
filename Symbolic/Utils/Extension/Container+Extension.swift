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

extension Array where Element: Hashable {
    func intersection(_ other: Self) -> Set<Element> {
        Set(self).intersection(other)
    }

    func subtracting(_ other: Self) -> Self {
        let intersection = self.intersection(other)
        return filter { intersection.contains($0) }
    }
}
