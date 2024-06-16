import Combine
import Foundation

protocol SelfTransformable {
    func map<T>(_ transform: (Self) -> T) -> T
}

extension SelfTransformable {
    func map<T>(_ transform: (Self) -> T) -> T { transform(self) }
}

extension CGAffineTransform: SelfTransformable {}

// MARK: - Cloneable

protocol Cloneable {
    init(_: Self)
}

extension Cloneable {
    var cloned: Self { Self(self) }

    func cloned(_ transform: (inout Self) -> Void) -> Self {
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

extension Set: Cloneable {}

extension UUID: TriviallyCloneable {}

extension Dictionary: Cloneable where Key: Cloneable, Value: Cloneable {
    init(_ map: [Key: Value]) {
        self.init()
        for pair in map {
            self[pair.key.cloned] = pair.value.cloned
        }
    }
}

// MARK: - ReflectedStringConvertible

protocol ReflectedStringConvertible: CustomStringConvertible {}

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

protocol CancellableHolder: AnyObject {
    var cancellables: Set<AnyCancellable> { get set }
}

extension AnyCancellable {
    func store(in holder: CancellableHolder) {
        store(in: &holder.cancellables)
    }
}

protocol HashIdentifiable: Hashable, Identifiable {}

extension HashIdentifiable {
    var id: Int { hashValue }
}

protocol UniqueEquatable: Equatable {}

extension UniqueEquatable {
    static func == (_: Self, _: Self) -> Bool { false }
}
