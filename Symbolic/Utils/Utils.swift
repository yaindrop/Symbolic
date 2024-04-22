import Foundation
import SwiftUI

extension UUID: Identifiable {
    public var id: UUID { self }
}

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

enum CornerPosition {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    var isTop: Bool { return self == .topLeft || self == .topRight }
    var isBottom: Bool { return self == .bottomLeft || self == .bottomRight }
    var isLeft: Bool { return self == .topLeft || self == .bottomLeft }
    var isRight: Bool { return self == .topRight || self == .bottomRight }
}

struct CornerPositionModifier: ViewModifier {
    var position: CornerPosition

    func body(content: Content) -> some View {
        HStack {
            if position.isRight { Spacer() }
            VStack {
                if position.isBottom { Spacer() }
                content
                if position.isTop { Spacer() }
            }
            if position.isLeft { Spacer() }
        }
    }
}
