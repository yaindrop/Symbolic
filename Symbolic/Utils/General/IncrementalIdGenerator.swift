import Foundation

class IncrementalIdGenerator {
    func generate() -> Int {
        let id = next
        next += 1
        return id
    }

    var current: Int { next - 1 }

    private var next: Int = 0
}
