import SwiftUI

// MARK: - SelectionMenu

extension ContextMenuView {
    struct SelectionMenu: View, SelectorHolder {
        class Selector: SelectorBase {
            override var syncUpdate: Bool { true }
            @Selected({ global.activeItem.selectionBounds }) var bounds
        }

        @SelectorWrapper var selector

        var body: some View {
            setupSelector {
                if let bounds = selector.bounds {
                    menu.contextMenu(bounds: bounds)
                }
            }
        }
    }
}

// MARK: private

extension ContextMenuView.SelectionMenu {
    @ViewBuilder var menu: some View {
        HStack {
            Button {} label: { Image(systemName: "arrow.up.left.and.arrow.down.right") }
                .frame(minWidth: 32)
                .tint(.label)

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
            Button { onGroup() } label: { Image(systemName: "square.on.square.squareshape.controlhandles") }
                .frame(minWidth: 32)
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

    func onGroup() {
        global.documentUpdater.groupSelection()
    }

    func onDelete() {
        global.documentUpdater.deleteSelection()
    }
}
