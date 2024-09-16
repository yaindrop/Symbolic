import SwiftUI

// MARK: - DocumentPanel

struct DocumentPanel: View, TracedView, SelectorHolder {
    class Selector: SelectorBase {}

    @SelectorWrapper var selector

    var body: some View { trace {
        setupSelector {
            content
        }
    } }
}

// MARK: private

extension DocumentPanel {
    @ViewBuilder private var content: some View {
        Properties()
//        Selection()
        Symbols()
    }
}
