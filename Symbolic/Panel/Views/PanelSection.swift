import SwiftUI

struct PanelSection<Content: View>: View, TracedView, ComputedSelectorHolder {
    let panelId: UUID, name: String
    @ViewBuilder let sectionContent: () -> Content

    struct SelectorProps: Equatable { let panelId: UUID }
    class Selector: SelectorBase {
        @Selected(animation: .default, { global.panel.floatingState(id: $0.panelId) }) var floatingState
    }

    @SelectorWrapper var selector

    var body: some View { trace {
        setupSelector(.init(panelId: panelId)) {
            content
        }
    } }
}

private extension PanelSection {
    var content: some View {
        VStack(spacing: 4) {
            title
            VStack(spacing: 0) {
                sectionContent()
            }
            .if(selector.floatingState == .primary) {
                $0.background(.ultraThickMaterial)
            } else: {
                $0.background(.background.secondary)
            }
            .clipRounded(radius: 12)
        }
    }

    var title: some View {
        HStack {
            Text(name)
                .font(.subheadline)
                .foregroundStyle(Color.secondaryLabel)
                .padding(.leading, 12)
            Spacer()
        }
    }
}
