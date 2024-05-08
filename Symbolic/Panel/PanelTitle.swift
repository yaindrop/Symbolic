import SwiftUI

struct PanelTitle: View {
    let name: String

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
    }
}
