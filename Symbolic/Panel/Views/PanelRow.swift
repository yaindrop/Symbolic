import SwiftUI

// MARK: - PanelRow

struct PanelRow<Content: View>: View, TracedView {
    var name: String? = nil
    @ViewBuilder let rowContent: () -> Content

    var body: some View { trace {
        content
    } }
}

// MARK: private

private extension PanelRow {
    var font: Font { .footnote }

    var height: Scalar { 32 }

    var padding: Scalar { 6 }

    @ViewBuilder var content: some View {
        HStack {
            if let name {
                Text(name)
                    .font(font)
                Spacer()
            }
            rowContent()
        }
        .frame(height: height)
        .padding(.vertical, padding)
    }
}
