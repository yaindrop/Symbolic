import Foundation

// MARK: - ClosedRange

extension ClosedRange {
    func clamp(_ value: Bound) -> Bound {
        lowerBound > value ? lowerBound : upperBound < value ? upperBound : value
    }

    init(start: Bound, end: Bound) { self = start < end ? start ... end : end ... start }
}
