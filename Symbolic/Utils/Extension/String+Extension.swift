import Foundation

extension String {
    func striding(_ stride: Int) -> [Substring] {
        guard stride > 0 else { return [] }
        var result: [Substring] = []
        var currIndex = startIndex
        while currIndex < endIndex {
            let nextIndex = index(currIndex, offsetBy: stride, limitedBy: endIndex) ?? endIndex
            result.append(self[currIndex ..< nextIndex])
            currIndex = nextIndex
        }
        return result
    }
}
