import SwiftUI

// MARK: - ItemsView

struct ItemsView: View, TracedView, SelectorHolder {
    class Selector: SelectorBase {
        override var configs: SelectorConfigs { .init(syncNotify: true) }
        @Selected({ global.viewport.sizedInfo }) var viewport
        @Selected({ global.item.allPaths }) var allPaths
        @Selected({ global.activeItem.focusedItemId }) var focusedItemId
    }

    @SelectorWrapper var selector

    var body: some View { trace {
        setupSelector {
            content
        }
    } }
}

// MARK: private

private extension ItemsView {
    @ViewBuilder var content: some View {
        AnimatableReader(selector.viewport) {
            let focusedItemId = selector.focusedItemId
            ForEach(selector.allPaths.filter { $0.id != focusedItemId }) { p in
                SUPath { path in p.append(to: &path) }
                    .stroke(Color(UIColor.label), style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
            }
            .transformEffect($0.worldToView)
        }
//        .blur(radius: 1)
    }
}
