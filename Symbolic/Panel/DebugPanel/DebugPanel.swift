import SwiftUI

struct DebugPanel: View, SelectorHolder {
    class Selector: SelectorBase {
        @Selected({ global.viewport.info }) var viewportInfo
    }

    @SelectorWrapper var selector

    var body: some View {
        setupSelector {
            content
        }
    }
}

private extension DebugPanel {
    @ViewBuilder var content: some View {
        viewport
    }

    @ViewBuilder var viewport: some View {
        PanelSection(name: "Viewport") {
            Row(name: "Origin", value: selector.viewportInfo.origin.shortDescription)
            Divider()
                .padding(.leading, 12)
            Row(name: "Scale", value: selector.viewportInfo.scale.shortDescription)
        }
    }
}

private struct Row: View {
    let name: String
    let value: String

    var body: some View {
        HStack {
            Text(name)
                .font(.callout)
            Spacer()
            Text(value)
                .font(.callout)
                .padding(.vertical, 4)
        }
        .padding(12)
    }
}
