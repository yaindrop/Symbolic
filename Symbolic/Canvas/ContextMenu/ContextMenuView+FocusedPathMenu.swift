import SwiftUI

private extension GlobalStore {
    func toggleSelectingNodes() {
        if focusedPath.selectingNodes {
            focusedPath.clear()
        } else {
            focusedPath.setSelectingNodes(true)
        }
    }
}

// MARK: - FocusedPathMenu

extension ContextMenuView {
    struct FocusedPathMenu: View, SelectorHolder {
        class Selector: SelectorBase {
            override var syncUpdate: Bool { true }
            @Selected({ global.activeItem.focusedPathBounds }) var bounds
            @Selected({ global.focusedPath.selectingNodes }) var selectingNodes
            @Selected({ global.focusedPath.activeNodeIds.isEmpty || global.focusedPath.selectingNodes }) var visible
        }

        @SelectorWrapper var selector

        var body: some View {
            setupSelector {
                if let bounds = selector.bounds, selector.visible {
                    menu.contextMenu(bounds: bounds)
                }
            }
        }

        // MARK: private

        @ViewBuilder private var menu: some View {
            HStack {
                Button {} label: { Image(systemName: "arrow.up.left.and.arrow.down.right") }
                    .frame(minWidth: 32)
                    .tint(.label)

                Button { onToggleSelectingNodes() } label: { Image(systemName: "checklist") }
                    .frame(minWidth: 32)
                    .if(!selector.selectingNodes) { $0.tint(.label) }

                Divider()

                Button {} label: { Image(systemName: "lock") }
                    .frame(minWidth: 32)
                    .tint(.label)
                Menu {
                    Button("Front", systemImage: "square.3.layers.3d.top.filled") {}
                    Button("Move above") {}
                    Button("Move below") {}
                    Button("Back", systemImage: "square.3.layers.3d.bottom.filled") {}
                } label: { Image(systemName: "square.3.layers.3d") }
                    .frame(minWidth: 32)
                    .menuOrder(.fixed)
                    .tint(.label)

                Divider()

                Menu {
                    Button("Copy", systemImage: "doc.on.doc") {}
                    Button("Cut", systemImage: "scissors") {}
                    Button("Duplicate", systemImage: "plus.square.on.square") {}
                } label: { Image(systemName: "doc.on.doc") }
                    .frame(minWidth: 32)
                    .menuOrder(.fixed)
                    .tint(.label)
                Button(role: .destructive) { onDelete() } label: { Image(systemName: "trash") }
                    .frame(minWidth: 32)
            }
        }

        private func onToggleSelectingNodes() {
            global.toggleSelectingNodes()
        }

        private func onUngroup() {}

        private func onDelete() {}
    }
}
