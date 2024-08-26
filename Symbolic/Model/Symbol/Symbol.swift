import Foundation

struct Symbol: Identifiable, Equatable, Codable, TriviallyCloneable {
    let id: UUID
    var origin: Point2
    var size: CGSize
}

extension Symbol {
    var boundingRect: CGRect {
        .init(origin: origin, size: size)
    }

    var symbolToWorld: CGAffineTransform {
        .init(translation: .init(origin))
    }

    var worldToSymbol: CGAffineTransform {
        symbolToWorld.inverted()
    }
}

extension Symbol: CustomStringConvertible {
    var description: String {
        "Symbol(id: \(id.shortDescription), origin: \(origin), size: \(size))"
    }
}
