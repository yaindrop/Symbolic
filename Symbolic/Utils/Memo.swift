import Foundation
import SwiftUI

// MARK: - Monostate

enum Monostate { case value }

extension Monostate: Equatable {}

extension Monostate: CustomStringConvertible {
    var description: String { "_" }
}

// MARK: - EquatableTuple

struct EquatableTuple<T0: Equatable, T1: Equatable, T2: Equatable, T3: Equatable, T4: Equatable, T5: Equatable>: Equatable {
    let v0: T0, v1: T1, v2: T2, v3: T3, v4: T4, v5: T5
    var tuple: (T0, T1, T2, T3, T4, T5) { (v0, v1, v2, v3, v4, v5) }
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.tuple == rhs.tuple }

    init(_ v0: T0, _ v1: T1, _ v2: T2, _ v3: T3, _ v4: T4, _ v5: T5) {
        self.v0 = v0
        self.v1 = v1
        self.v2 = v2
        self.v3 = v3
        self.v4 = v4
        self.v5 = v5
    }
}

extension EquatableTuple where T2 == Monostate, T3 == Monostate, T4 == Monostate, T5 == Monostate {
    init(_ v0: T0, _ v1: T1) { self.init(v0, v1, .value, .value, .value, .value) }
}

extension EquatableTuple where T3 == Monostate, T4 == Monostate, T5 == Monostate {
    init(_ v0: T0, _ v1: T1, _ v2: T2) { self.init(v0, v1, v2, .value, .value, .value) }
}

extension EquatableTuple where T4 == Monostate, T5 == Monostate {
    init(_ v0: T0, _ v1: T1, _ v2: T2, _ v3: T3) { self.init(v0, v1, v2, v3, .value, .value) }
}

extension EquatableTuple where T5 == Monostate {
    init(_ v0: T0, _ v1: T1, _ v2: T2, _ v3: T3, _ v4: T4) { self.init(v0, v1, v2, v3, v4, .value) }
}

// MARK: - EquatableTupleBuilder

@resultBuilder
struct EquatableTupleBuilder {
    static func buildBlock<T0: Equatable>(_ v0: T0) -> some Equatable {
        v0
    }

    static func buildBlock<T0: Equatable, T1: Equatable>(_ v0: T0, _ v1: T1) -> some Equatable {
        EquatableTuple(v0, v1)
    }

    static func buildBlock<T0: Equatable, T1: Equatable, T2: Equatable>(_ v0: T0, _ v1: T1, _ v2: T2) -> some Equatable {
        EquatableTuple(v0, v1, v2)
    }

    static func buildBlock<T0: Equatable, T1: Equatable, T2: Equatable, T3: Equatable>(_ v0: T0, _ v1: T1, _ v2: T2, _ v3: T3) -> some Equatable {
        EquatableTuple(v0, v1, v2, v3)
    }

    static func buildBlock<T0: Equatable, T1: Equatable, T2: Equatable, T3: Equatable, T4: Equatable>(_ v0: T0, _ v1: T1, _ v2: T2, _ v3: T3, _ v4: T4) -> some Equatable {
        EquatableTuple(v0, v1, v2, v3, v4)
    }

    static func buildBlock<T0: Equatable, T1: Equatable, T2: Equatable, T3: Equatable, T4: Equatable, T5: Equatable>(_ v0: T0, _ v1: T1, _ v2: T2, _ v3: T3, _ v4: T4, _ v5: T5) -> some Equatable {
        EquatableTuple(v0, v1, v2, v3, v4, v5)
    }
}

// MARK: - EquatableByKey

protocol EquatableByKey: Equatable {
    associatedtype Key: Equatable
    var equatableKey: Key { get }
}

extension EquatableByKey {
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.equatableKey == rhs.equatableKey }
}

// MARK: - EquatableByTuple

protocol EquatableByTuple: Equatable {
    associatedtype Tuple: Equatable
    @EquatableTupleBuilder var equatableTuple: Tuple { get }
}

extension EquatableByTuple {
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.equatableTuple == rhs.equatableTuple }
}

// MARK: - Memo

struct Memo<Key: Equatable, Content: View>: View, Equatable {
    let key: Key
    @ViewBuilder let content: () -> Content

    var body: some View { tracer.range("Memo") {
        content()
    } }

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.key == rhs.key }

    init(_ key: Key, @ViewBuilder _ content: @escaping () -> Content) {
        self.key = key
        self.content = content
    }

    init(@EquatableTupleBuilder _ key: () -> Key, @ViewBuilder _ content: @escaping () -> Content) {
        self.init(key(), content)
    }
}
