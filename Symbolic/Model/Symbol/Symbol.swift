import Foundation

struct Symbol: Identifiable, Equatable, Codable, TriviallyCloneable {
    let id: UUID
    var origin: Point2
    var size: CGSize
}

extension Symbol {
    var rect: CGRect {
        .init(origin: origin, size: size)
    }
}

extension Symbol: CustomStringConvertible {
    var description: String {
        "Symbol(id: \(id.shortDescription), origin: \(origin), size: \(size))"
    }
}
