import Foundation
import SwiftUI

enum ContextMenuData {
    struct PathNode {
        let pathId: UUID, nodeId: UUID
    }

    struct PathEdge {
        let pathId: UUID, fromNodeId: UUID
    }

    struct Path {
        let pathId: UUID
    }

    struct Selection {
        let pathIds: [UUID]
    }
}

class ContextMenuStore: Store {}

struct ContextMenu: View {
    var onDelete: (() -> Void)?
    var onGroup: (() -> Void)?

    @State var size: CGSize = .zero

    var body: some View {
        HStack {
            Button { onGroup?() } label: { Image(systemName: "rectangle.3.group") }
            Divider()
            Button(role: .destructive) { onDelete?() } label: { Image(systemName: "trash") }
        }
        .padding(12)
        .background(.thickMaterial)
        .fixedSize()
        .sizeReader { size = $0 }
        .cornerRadius(size.height / 2)
    }
}
