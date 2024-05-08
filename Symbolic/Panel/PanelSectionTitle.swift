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
