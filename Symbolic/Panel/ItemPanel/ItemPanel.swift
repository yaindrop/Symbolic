import SwiftUI

// MARK: - ItemPanel

struct ItemPanel: View, TracedView {
    var body: some View { trace {
        content
    } }
}

// MARK: private

extension ItemPanel {
    @ViewBuilder private var content: some View {
        Selection()
        Items()
    }
}
