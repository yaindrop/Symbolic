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

extension Color {
    // MARK: - Text Colors

    static let lightText = Color(.lightText)
    static let darkText = Color(.darkText)
    static let placeholderText = Color(.placeholderText)

    // MARK: - Label Colors

    static let label = Color(.label)
    static let secondaryLabel = Color(.secondaryLabel)
    static let tertiaryLabel = Color(.tertiaryLabel)
    static let quaternaryLabel = Color(.quaternaryLabel)

    // MARK: - Background Colors

    static let systemBackground = Color(.systemBackground)
    static let secondarySystemBackground = Color(.secondarySystemBackground)
    static let tertiarySystemBackground = Color(.tertiarySystemBackground)

    // MARK: - Fill Colors

    static let systemFill = Color(.systemFill)
    static let secondarySystemFill = Color(.secondarySystemFill)
    static let tertiarySystemFill = Color(.tertiarySystemFill)
    static let quaternarySystemFill = Color(.quaternarySystemFill)

    // MARK: - Grouped Background Colors

    static let systemGroupedBackground = Color(.systemGroupedBackground)
    static let secondarySystemGroupedBackground = Color(.secondarySystemGroupedBackground)
    static let tertiarySystemGroupedBackground = Color(.tertiarySystemGroupedBackground)

    // MARK: - Gray Colors

    static let systemGray = Color(.systemGray)
    static let systemGray2 = Color(.systemGray2)
    static let systemGray3 = Color(.systemGray3)
    static let systemGray4 = Color(.systemGray4)
    static let systemGray5 = Color(.systemGray5)
    static let systemGray6 = Color(.systemGray6)

    // MARK: - Other Colors

    static let separator = Color(.separator)
    static let opaqueSeparator = Color(.opaqueSeparator)
    static let link = Color(.link)

    // MARK: System Colors

    static let systemBlue = Color(.systemBlue)
    static let systemPurple = Color(.systemPurple)
    static let systemGreen = Color(.systemGreen)
    static let systemYellow = Color(.systemYellow)
    static let systemOrange = Color(.systemOrange)
    static let systemPink = Color(.systemPink)
    static let systemRed = Color(.systemRed)
    static let systemTeal = Color(.systemTeal)
    static let systemIndigo = Color(.systemIndigo)
}
