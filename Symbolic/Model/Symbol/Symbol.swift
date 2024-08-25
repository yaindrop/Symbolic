import Foundation

struct Symbol: Identifiable, Equatable, Codable, TriviallyCloneable {
    let id: UUID
    var origin: Point2
    var size: CGSize
}

extension Symbol: CustomStringConvertible {
    var description: String {
        "Symbol(id: \(id.shortDescription), origin: \(origin), size: \(size))"
    }
}
