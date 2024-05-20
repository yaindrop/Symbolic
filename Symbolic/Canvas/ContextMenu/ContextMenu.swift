import Foundation
import SwiftUI

struct ContextMenu: View {
    var onDelete: (() -> Void)?

    @State var size: CGSize = .zero

    var body: some View {
        HStack {
            Image(systemName: "rectangle.3.group")
            Divider()
            Button("", systemImage: "trash", role: .destructive) { onDelete?() }
        }
        .padding(12)
        .background(.thickMaterial)
        .fixedSize()
        .viewSizeReader { size = $0 }
        .cornerRadius(size.height / 2)
    }
}
