import Foundation

struct OrderedMap<Key: Hashable, Value> {
    private(set) var dict: [Key: Value] = [:]
    private(set) var keys: [Key] = []

    var count: Int { keys.count }

    var values: [Value] { keys.map { dict[$0]! } }

    subscript(key: Key) -> Value? {
        get { dict[key] }
        set {
            guard let newValue else {
                removeValue(forKey: key)
                return
            }
            if dict[key] == nil {
                keys.append(key)
            }
            dict[key] = newValue
        }
    }

    func value(at index: Int) -> Value? {
        guard index >= 0 && index < keys.count else {
            return nil
        }
        return dict[keys[index]]
    }

    mutating func removeValue(forKey key: Key) {
        guard dict[key] != nil else { return }
        dict.removeValue(forKey: key)
        keys = keys.filter { $0 != key }
    }

    mutating func removeAll() {
        dict.removeAll()
        keys.removeAll()
    }
}

extension OrderedMap: Cloneable where Key: Cloneable, Value: Cloneable {
    init(_ map: OrderedMap<Key, Value>) {
        dict = map.dict.reduce(into: [Key: Value]()) { $0[$1.key.cloned] = $1.value.cloned }
        keys = map.keys.map { Key($0) }
    }
}
