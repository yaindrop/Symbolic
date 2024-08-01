import SwiftUI

let debugContextualViews = false

// MARK: - ContextualViewData

struct ContextualViewData {
    var labelFont: Font = .body
    var rowHeight: Scalar = 32
    var rowPadding: EdgeInsets = .init()
    var dividerPadding: EdgeInsets = .init()
}

private struct ContextualViewDataKey: EnvironmentKey {
    static let defaultValue: ContextualViewData = .init()
}

extension EnvironmentValues {
    var contextualViewData: ContextualViewData {
        get { self[ContextualViewDataKey.self] }
        set { self[ContextualViewDataKey.self] = newValue }
    }
}

// MARK: - ContextualRow

struct ContextualRow<Content: View>: View, TracedView {
    @Environment(\.contextualViewData) var data

    var label: String? = nil
    @ViewBuilder let rowContent: () -> Content

    var body: some View { trace("body, label: \(label ?? "nil")") {
        content
    } }
}

// MARK: private

private extension ContextualRow {
    @ViewBuilder var content: some View {
        HStack {
            if let label {
                Text(label)
                    .font(data.labelFont)
                Spacer()
            }
            rowContent()
        }
        .frame(height: data.rowHeight)
        .border(debugContextualViews ? .blue : .clear)
        .padding(data.rowPadding)
        .background(debugContextualViews ? .blue.opacity(0.1) : .clear)
    }
}

// MARK: - ContextualDivider

struct ContextualDivider: View {
    @Environment(\.contextualViewData) var data

    var body: some View {
        Divider()
            .padding(data.dividerPadding)
    }
}

// MARK: - ContextualFontModifier

struct ContextualFontModifier: ViewModifier {
    @Environment(\.contextualViewData) var data

    func body(content: Content) -> some View {
        content
            .font(data.labelFont)
    }
}

extension View {
    func contextualFont() -> some View {
        modifier(ContextualFontModifier())
    }
}
