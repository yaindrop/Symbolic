import SwiftUI

struct RootView: View, TracedView, SelectorHolder {
    class Selector: SelectorBase {
        @Selected(animation: .fast, { global.root.showCanvas }) var showCanvas
    }

    @SelectorWrapper var selector

    var body: some View { trace {
        setupSelector {
            ZStack {
                NavigationSplitView(preferredCompactColumn: .constant(.detail)) {
                    SidebarView()
                } detail: {
                    DocumentsView()
                }
                if selector.showCanvas {
                    CanvasView()
                        .background(.background)
                }
            }
        }
    }}
}
