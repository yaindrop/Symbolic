import Foundation

// MARK: - OrderedMap

struct OrderedMap<Key: Hashable, Value> {
    private(set) var dict: [Key: Value] = [:]
    private(set) var keys: [Key] = []
    private var indexOf: [Key: Int] = [:]

    init(_ dict: [Key: Value]) {
        self.dict = dict
        keys = Array(dict.keys)
        refreshIndexOf()
    }

    init(keys: [Key], getValue: (Key) -> Value) {
        for key in keys {
            dict[key] = getValue(key)
            self.keys.append(key)
        }
        refreshIndexOf()
    }

    init(values: [Value], getKey: (Value) -> Key) {
        for value in values {
            let key = getKey(value)
            dict[key] = value
            keys.append(key)
        }
        refreshIndexOf()
    }
}

extension OrderedMap {
    var count: Int { keys.count }

    var values: [Value] { keys.map { dict[$0]! } }

    func get(_ key: Key) -> Value? { dict[key] }

    func index(of key: Key) -> Int? { indexOf[key] }

    mutating func removeAll() {
        dict.removeAll()
        keys.removeAll()
        indexOf.removeAll()
    }
}

// MARK: map-like api

extension OrderedMap {
    subscript(key: Key) -> Value? {
        get { get(key) }
        set { set(key: key, value: newValue) }
    }

    @discardableResult
    mutating func updateValue(_ value: Value, forKey key: Key) -> Value? {
        let replaced = dict.updateValue(value, forKey: key)
        if replaced == nil {
            keys.append(key)
            indexOf[key] = keys.count - 1
        }
        return replaced
    }

    @discardableResult
    mutating func removeValue(forKey key: Key) -> Value? {
        let removed = dict.removeValue(forKey: key)
        if removed != nil {
            guard let index = keys.firstIndex(of: key) else { return removed }
            keys.remove(at: index)
            refreshIndexOf()
        }
        return removed
    }
}

// MARK: array-like api

extension OrderedMap {
    subscript(index: Int) -> Value? {
        get { value(index: index) }
        set { setValue(index: index, value: newValue) }
    }

    var indices: Range<Int> { keys.indices }

    var first: Value? {
        guard let k = keys.first else { return nil }
        return dict[k]
    }

    var last: Value? {
        guard let k = keys.last else { return nil }
        return dict[k]
    }

    mutating func append(_ newElement: Element) {
        let (key, value) = newElement
        updateValue(value, forKey: key)
    }

    @discardableResult
    mutating func insert(_ newElement: Element, at i: Int) -> Bool {
        guard (0 ... keys.endIndex).contains(i) else { return false }
        let (key, value) = newElement
        let replaced = updateValue(value, forKey: key)
        if replaced == nil {
            keys.removeLast()
            keys.insert(key, at: i)
            refreshIndexOf()
            return true
        }
        return false
    }

    @discardableResult
    mutating func remove(at index: Int) -> Element? {
        guard keys.indices.contains(index) else { return nil }
        let key = keys[index]
        guard let removed = removeValue(forKey: key) else { return nil }
        return (key, removed)
    }
}

// MARK: special api

extension OrderedMap {
    mutating func mutateKeys(_ mutator: (inout [Key]) -> Void) {
        let mutated = keys.cloned { mutator(&$0) }
        if let newKey = mutated.first(where: { dict[$0] == nil }) {
            logError("Cannot introduce new key \(newKey) in mutateKeys")
            fatalError()
        }
        let mutatedSet = Set(mutated)
        let removed = keys.filter { k in !mutatedSet.contains(k) }

        removed.forEach { dict.removeValue(forKey: $0) }
        keys = mutated
        refreshIndexOf()
    }
}

// MARK: private

private extension OrderedMap {
    mutating func set(key: Key, value: Value?) {
        if let value {
            updateValue(value, forKey: key)
        } else {
            removeValue(forKey: key)
        }
    }

    func value(index: Int) -> Value? {
        guard keys.indices.contains(index) else { return nil }
        return dict[keys[index]]
    }

    mutating func setValue(index: Int, value: Value?) {
        guard keys.indices.contains(index) else { return }
        dict[keys[index]] = value
    }

    mutating func refreshIndexOf() {
        indexOf = keys.enumerated().reduce(into: [Key: Int]()) { dict, pair in dict[pair.element] = pair.offset }
    }
}

// MARK: - Key == Int

extension OrderedMap where Key == Int {
    subscript(key: Int) -> Value? {
        get { get(key) }
        set { set(key: key, value: newValue) }
    }

    subscript(index index: Int) -> Value? {
        get { value(index: index) }
        set { setValue(index: index, value: newValue) }
    }
}

// MARK: - ExpressibleByDictionaryLiteral

extension OrderedMap: ExpressibleByDictionaryLiteral {
    init(dictionaryLiteral elements: (Key, Value)...) {
        for (key, value) in elements {
            dict[key] = value
            keys.append(key)
        }
        refreshIndexOf()
    }
}

// MARK: - Cloneable

extension OrderedMap: Cloneable where Key: Cloneable, Value: Cloneable {
    init(_ map: OrderedMap<Key, Value>) {
        dict = map.dict.reduce(into: [Key: Value]()) { dict, pair in dict[pair.key.cloned] = pair.value.cloned }
        keys = map.keys.map { Key($0) }
        refreshIndexOf()
    }
}

extension OrderedMap: Equatable, EquatableBy where Value: Equatable {
    var equatableBy: some Equatable { keys; values }
}

// MARK: - Sequence

extension OrderedMap: Sequence {
    struct Iterator: IteratorProtocol {
        let dict: [Key: Value]
        var keysIterator: Array<Key>.Iterator

        init(keys: [Key], dict: [Key: Value]) {
            self.dict = dict
            keysIterator = keys.makeIterator()
        }

        mutating func next() -> (Key, Value)? {
            guard let key = keysIterator.next(), let value = dict[key] else { return nil }
            return (key, value)
        }
    }

    func makeIterator() -> Iterator { .init(keys: keys, dict: dict) }
}
