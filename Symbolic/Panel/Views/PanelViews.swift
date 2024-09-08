import SwiftUI

// MARK: - PanelSection

struct PanelSection<Content: View>: View, TracedView {
    let name: String
    @ViewBuilder let sectionContent: () -> Content

    var body: some View { trace {
        content
    } }
}

// MARK: private

private extension PanelSection {
    var content: some View {
        VStack(spacing: 4) {
            title
            VStack(spacing: 0) {
                sectionContent()
                    .environment(\.contextualViewData, contextualViewData)
            }
            .background { PanelSectionBackground() }
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

    var contextualViewData: ContextualViewData {
        .init(
            labelFont: .callout,
            rowHeight: 36,
            rowPadding: .init(top: 6, leading: 12, bottom: 6, trailing: 12),
            dividerPadding: .init(top: 0, leading: 12, bottom: 0, trailing: 0)
        )
    }
}

// MARK: - Background

private struct PanelSectionBackground: View, TracedView {
    @Environment(\.panelFloatingStyle) var floatingStyle

    var body: some View { trace {
        content
    } }
}

private extension PanelSectionBackground {
    var content: some View {
        Rectangle()
            .if(floatingStyle.isPrimary) {
                $0.fill(.ultraThinMaterial)
            } else: {
                $0.fill(.background.secondary.opacity(0.8))
            }
    }
}
