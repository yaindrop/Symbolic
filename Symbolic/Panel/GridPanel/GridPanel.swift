import SwiftUI

// MARK: - HistoryPanel

struct GridPanel: View, TracedView, SelectorHolder {
    class Selector: SelectorBase {
        @Selected({ global.document.activeDocument }) var document
    }

    @SelectorWrapper var selector

    @StateObject private var scrollViewModel = ManagedScrollViewModel()

    var body: some View { trace {
        setupSelector {
            content
        }
    } }
}

// MARK: private

extension GridPanel {
    @ViewBuilder private var content: some View {
        PanelBody(name: "Grid", maxHeight: 400) { _ in
            events
        }
    }

    @ViewBuilder private var events: some View {
//        PanelSection(name: "Events") {
//            ForEach(selector.document.events) {
        ////                EventRow(event: $0)
//                if $0 != selector.document.events.last {
//                    Divider().padding(.leading, 12)
//                }
//            }
//        }
        PanelSection(name: "Preview") {
            GridPreview()
        }
    }
}

struct GridPreview: View, TracedView, SelectorHolder {
    class Selector: SelectorBase {
        @Selected({ global.grid.gridStack }) var document
    }

    @SelectorWrapper var selector

    @State private var size: CGSize = .zero

    var body: some View { trace {
        setupSelector {
            content
        }
    } }
}

extension GridPreview {
    @ViewBuilder private var content: some View {
        CartesianGridView(grid: .init(cellSize: 8), viewport: .init(size: size, center: .zero, scale: 10), lineColor: .red)
            .frame(maxWidth: .infinity)
            .aspectRatio(contentMode: .fit)
            .clipped()
            .sizeReader { size = $0 }
    }
}
