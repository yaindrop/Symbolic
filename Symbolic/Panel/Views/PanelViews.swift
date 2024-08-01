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
            }
            .background { PanelSectionBackground() }
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

// MARK: - Background

private struct PanelSectionBackground: View, TracedView {
    @Environment(\.panelAppearance) var panelAppearance

    var body: some View { trace {
        content
    } }
}

private extension PanelSectionBackground {
    var content: some View {
        Rectangle()
            .if(panelAppearance == .floatingSecondary) {
                $0.fill(.background.secondary.opacity(0.8))
            } else: {
                $0.fill(.ultraThinMaterial)
            }
            .clipRounded(radius: 12)
    }
}

// MARK: - PanelSectionRow

struct PanelSectionRow<Content: View>: View, TracedView {
    var label: String? = nil
    @ViewBuilder let rowContent: () -> Content

    var body: some View { trace {
        content
    } }
}

// MARK: private

private extension PanelSectionRow {
    @ViewBuilder var content: some View {
        HStack {
            if let label {
                Text(label)
                    .font(.callout)
                Spacer()
            }
            rowContent()
        }
        .frame(height: 36)
        .padding(size: .init(12, 6))
    }
}

// MARK: - PanelSectionDivider

struct PanelSectionDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 12)
    }
}
