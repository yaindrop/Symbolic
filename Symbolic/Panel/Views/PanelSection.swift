import SwiftUI

struct PanelSectionTitle: View {
    let name: String

    var body: some View {
        HStack {
            Text(name)
                .font(.subheadline)
                .foregroundStyle(Color.secondaryLabel)
                .padding(.leading, 12)
            Spacer()
        }
    }
}

struct PanelSection<Content: View>: View {
    let name: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 4) {
            PanelSectionTitle(name: name)
            VStack(spacing: 0) {
                content()
            }
            .background(.ultraThickMaterial)
            .clipRounded(radius: 12)
        }
    }
}
