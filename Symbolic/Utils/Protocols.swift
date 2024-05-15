import Foundation

protocol SelfTransformable {
    func apply<T>(_ transform: (Self) -> T) -> T
}

extension SelfTransformable {
    func apply<T>(_ transform: (Self) -> T) -> T { transform(self) }
}

extension CGAffineTransform: SelfTransformable {}

// MARK: - Cloneable

protocol Cloneable {
    init(_: Self)
}

extension Cloneable {
    var cloned: Self { Self(self) }

    func with(_ transform: (inout Self) -> Void) -> Self {
        var cloned = cloned
        transform(&cloned)
        return cloned
    }
}

protocol TriviallyCloneable: Cloneable {}

extension TriviallyCloneable {
    init(_ v: Self) { self = v }
}

extension Array: Cloneable {}

extension UUID: TriviallyCloneable {}

// MARK: - ReflectedStringConvertible

public protocol ReflectedStringConvertible: CustomStringConvertible { }

extension ReflectedStringConvertible {
    public var description: String {
        let mirror = Mirror(reflecting: self)
        let propertiesStr = mirror.children.compactMap { label, value in
            guard let label = label else { return nil }
            return "\(label): \(value)"
        }.joined(separator: ", ")
        return "\(mirror.subjectType)(\(propertiesStr))"
    }
}