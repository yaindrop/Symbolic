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
            }
        }
        .background(.ultraThinMaterial)
        .clipRounded(radius: 12)
        .frame(maxWidth: 240)
    }
}

// MARK: - PopoverRow

struct PopoverRow<Content: View>: View, TracedView {
    var label: String? = nil
    @ViewBuilder let rowContent: () -> Content

    var body: some View { trace {
        content
    } }
}

// MARK: private

private extension PopoverRow {
    @ViewBuilder var content: some View {
        HStack {
            if let label {
                Text(label)
                    .font(.footnote)
                Spacer()
            }
            rowContent()
        }
        .frame(height: 32)
        .padding(size: .init(12, 6))
    }
}

// MARK: - PopoverDivider

struct PopoverDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 12)
    }
}
