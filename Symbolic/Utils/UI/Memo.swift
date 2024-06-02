import Foundation
import SwiftUI

// MARK: - Memo

struct Memo<Value: Equatable, Content: View>: View, EquatableBy {
    let equatableBy: Value
    @ViewBuilder let content: () -> Content

    var body: some View { tracer.range("Memo") {
        content()
    } }

    init(@ViewBuilder _ content: @escaping () -> Content, @EquatableBuilder deps: () -> Value) {
        equatableBy = deps()
        self.content = content
    }
}
