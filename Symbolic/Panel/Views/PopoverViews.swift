import SwiftUI

// MARK: - PopoverBody

struct PopoverBody<Title: View, Content: View>: View, TracedView {
    @ViewBuilder let popoverTitle: () -> Title
    @ViewBuilder let popoverContent: () -> Content

    var body: some View { trace {
        content
    } }
}

// MARK: private

private extension PopoverBody {
    var content: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                popoverTitle()
            }
            .padding(12)
            .background(.ultraThickMaterial.shadow(.drop(color: .label.opacity(0.05), radius: 6)))
            VStack(spacing: 0) {
                popoverContent()
                    .environment(\.contextualViewData, contextualViewData)
            }
        }
        .background(.ultraThinMaterial)
        .clipRounded(radius: 12)
        .frame(maxWidth: 240)
    }

    var contextualViewData: ContextualViewData {
        .init(
            labelFont: .footnote,
            rowHeight: 32,
            rowPadding: .init(top: 6, leading: 12, bottom: 6, trailing: 12),
            dividerPadding: .init(top: 0, leading: 12, bottom: 0, trailing: 0)
        )
    }
}
