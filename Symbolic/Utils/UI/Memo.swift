import SwiftUI

// MARK: - Memo

struct Memo<Value: Equatable, Content: View>: View, TracedView, EquatableBy {
    let equatableBy: Value
    @ViewBuilder let content: () -> Content

    var body: some View { trace {
        content()
    } }

    init(@ViewBuilder _ content: @escaping () -> Content, @EquatableBuilder deps: () -> Value) {
        equatableBy = deps()
        self.content = content
    }
}
