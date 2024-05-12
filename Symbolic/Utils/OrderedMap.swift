import Foundation

struct OrderedMap<Key: Hashable, Value> {
    private(set) var dict: [Key: Value] = [:]
    private(set) var keys: [Key] = []

    var count: Int { keys.count }

    var values: [Value] { keys.map { dict[$0]! } }

    subscript(key: Key) -> Value? {
        get { dict[key] }
        set {
            if let newValue {
                if dict.updateValue(newValue, forKey: key) == nil {
                    keys.append(key)
                }
            } else {
                removeValue(forKey: key)
            }
        }
    }

    func value(at index: Int) -> Value? {
        guard index >= 0 && index < keys.count else { return nil }
        return dict[keys[index]]
    }

    mutating func removeValue(forKey key: Key) {
        if let index = keys.firstIndex(of: key) {
            dict.removeValue(forKey: key)
            keys.remove(at: index)
        }
    }

    mutating func removeAll() {
        dict.removeAll()
        keys.removeAll()
    }
}

extension OrderedMap: Cloneable where Key: Cloneable, Value: Cloneable {
    init(_ map: OrderedMap<Key, Value>) {
        dict = map.dict.reduce(into: [Key: Value]()) { dict, pair in dict[pair.key.cloned] = pair.value.cloned }
        keys = map.keys.map { Key($0) }
    }
}
