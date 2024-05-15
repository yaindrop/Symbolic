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
struct EquatableBuilder {
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

// MARK: - EquatableBy

protocol EquatableBy: Equatable {
    associatedtype Value: Equatable
    @EquatableBuilder var equatableBy: Value { get }
}

extension EquatableBy {
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.equatableBy == rhs.equatableBy }
}

// MARK: - Memo

struct Memo<Value: Equatable, Content: View>: View, EquatableBy {
    let equatableBy: Value
    @ViewBuilder let content: () -> Content

    var body: some View { tracer.range("Memo") {
        content()
    } }

    init(@ViewBuilder _ content: @escaping () -> Content, @EquatableBuilder deps: () -> Value) {
        equatableBy = deps()
        self.content = content
    }
}
