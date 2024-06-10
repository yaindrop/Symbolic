import SwiftUI

struct PanelTitle: View {
    let panelId: UUID, name: String

    var body: some View {
        HStack {
            Spacer()
            Text(name)
                .font(.headline)
                .fontWeight(.semibold)
                .padding(.vertical, 8)
            Spacer()
        }
        .padding(12)
        .invisibleSoildOverlay()
        .draggable(panelId.uuidString.data(using: .utf8) ?? .init())
    }
}
