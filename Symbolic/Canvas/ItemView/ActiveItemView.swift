import SwiftUI

// MARK: - ActiveItemView

struct ActiveItemView: View, TracedView, SelectorHolder {
    class Selector: SelectorBase {
        @Selected({ global.activeItem.activePaths }) var activePaths
        @Selected({ global.activeItem.activeGroups }) var activeGroups
    }

    @SelectorWrapper var selector

    var body: some View { trace {
        setupSelector {
            content
        }
    } }
}

private extension ActiveItemView {
    @ViewBuilder var content: some View {
        ForEach(selector.activeGroups) {
            GroupBounds(group: $0)
        }
        ForEach(selector.activePaths) {
            PathBounds(pathId: $0.id)
        }
        SelectionBounds()
    }
}
