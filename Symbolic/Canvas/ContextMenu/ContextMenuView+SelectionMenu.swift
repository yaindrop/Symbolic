import SwiftUI

// MARK: - SelectionMenu

extension ContextMenuView {
    struct SelectionMenu: View, SelectorHolder {
        class Selector: SelectorBase {
            override var configs: SelectorConfigs { .init(syncNotify: true) }
            @Selected({ global.viewport.sizedInfo }) var viewport
            @Selected({ global.activeItem.selectionBounds }) var bounds
            @Selected({ global.activeItem.selectionOutset }) var outset
        }

        @SelectorWrapper var selector

        var body: some View {
            setupSelector {
                content
            }
        }
    }
}

// MARK: private

extension ContextMenuView.SelectionMenu {
    @ViewBuilder var content: some View {
        if let bounds = selector.bounds {
            ViewportWorldToView(frame: bounds, viewport: selector.viewport) {
                menu.contextMenu(bounds: $0.outset(by: selector.outset))
            }
        }
    }

    @ViewBuilder var menu: some View {
        HStack {
            Button {
                if let bounds = selector.bounds {
                    global.viewportUpdater.zoomTo(rect: bounds)
                }
            } label: { Image(systemName: "arrow.up.left.and.arrow.down.right") }
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
                .menuOrder(.fixed)
                .frame(minWidth: 32)
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
                .menuOrder(.fixed)
                .frame(minWidth: 32)
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
