import SwiftUI

// MARK: - PanelSection

struct PanelSection<Content: View>: View, TracedView, ComputedSelectorHolder {
    @Environment(\.panelId) var panelId

    let name: String
    @ViewBuilder let sectionContent: () -> Content

    struct SelectorProps: Equatable { let panelId: UUID }
    class Selector: SelectorBase {
        @Selected(animation: .default, { global.panel.appearance(id: $0.panelId) }) var appearance
    }

    @SelectorWrapper var selector

    var body: some View { trace {
        setupSelector(.init(panelId: panelId)) {
            content
        }
    } }
}

// MARK: private

private extension PanelSection {
    var content: some View {
        VStack(spacing: 4) {
            title
            VStack(spacing: 0) {
                sectionContent()
            }
            .if(selector.appearance == .floatingSecondary) {
                $0.background(.background.secondary)
            } else: {
                $0.background(.ultraThickMaterial)
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
