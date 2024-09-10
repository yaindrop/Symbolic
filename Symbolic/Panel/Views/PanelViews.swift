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
            .background { PanelBackground() }
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

// MARK: - PanelBackground

struct PanelBackground: View, TracedView {
    var body: some View { trace {
        content
    } }
}

private extension PanelBackground {
    var content: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
    }
}

// MARK: - PanelPlaceholder

struct PanelPlaceholder: View, TracedView {
    let text: String

    var body: some View { trace {
        content
    } }
}

// MARK: private

private extension PanelPlaceholder {
    var content: some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(Color.label.opacity(0.5))
            .frame(maxWidth: .infinity, idealHeight: 72)
            .background { PanelBackground() }
            .clipRounded(radius: 12)
    }
}
