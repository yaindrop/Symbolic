import Foundation

extension UUID: Identifiable {
    public var id: UUID { self }
}

extension UUID {
    var shortDescription: String { "#\(uuidString.prefix(4))" }
}
