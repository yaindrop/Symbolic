//
//  Box.swift
//  Symbolic
//
//  Created by Yaindrop on 2024/4/21.
//

import Foundation

class Box<T> {
    var value: T

    init(_ value: T) {
        self.value = value
    }
}

extension Box: Equatable where T: Equatable {
    static func == (lhs: Box<T>, rhs: Box<T>) -> Bool {
        return lhs.value == rhs.value
    }
}

extension Box: Comparable where T: Comparable {
    static func < (lhs: Box<T>, rhs: Box<T>) -> Bool {
        return lhs.value < rhs.value
    }
}

extension Box: Hashable where T: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(value)
    }
}

extension Box: CustomStringConvertible {
    var description: String {
        return "\(value)"
    }
}

extension Box: CustomDebugStringConvertible {
    var debugDescription: String {
        return "Box(\(value))"
    }
}

@propertyWrapper
struct Boxed<T> {
    private var box: Box<T>

    init(wrappedValue: T) {
        box = Box(wrappedValue)
    }

    var wrappedValue: T {
        get { box.value }
        set { box.value = newValue }
    }
}
