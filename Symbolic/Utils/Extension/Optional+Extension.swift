import Foundation

extension Optional {
    func map<U>(_ then: (Wrapped) throws -> U?) rethrows -> U? {
        if case let .some(v) = self {
            return try then(v)
        }
        return nil
    }

    mutating func forSome(_ then: (inout Wrapped) throws -> Void, else: (() throws -> Void)? = nil) rethrows {
        if case .some = self {
            try then(&self!)
        } else {
            try `else`?()
        }
    }
}
