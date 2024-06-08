import Foundation

class IncrementalIdGenerator {
    func generate() -> Int {
        let id = next
        next += 1
        return id
    }

    private var next: Int = 0
}
