import SwiftUI

// MARK: - global actions

private extension GlobalStores {
    var selectionBounds: CGRect? { activeItem.selectionBounds }

    func onZoom() {
        guard let selectionBounds else { return }
        viewportUpdater.zoomTo(rect: selectionBounds)
    }

    func onGroup() {
        let groupId = UUID(),
            members = activeItem.selectedItems.map { $0.id }
        guard !members.isEmpty else { return }
        let inGroupId = item.commonAncestorId(of: members),
            inSymbolId = inGroupId == nil ? item.symbolId(of: members[0]) : nil
        documentUpdater.update(item: .group(.init(groupId: groupId, members: members, inSymbolId: inSymbolId, inGroupId: inGroupId)))
        activeItem.onTap(itemId: groupId)
    }

    func onDelete() {
        let pathIds = activeItem.selectedItems.map { $0.id }
        documentUpdater.update(path: .delete(.init(pathIds: pathIds)))
        activeItem.blur()
    }
}

// MARK: - SelectionMenu

extension ContextMenuView {
    struct SelectionMenu: View, SelectorHolder {
        @Environment(\.sizedViewport) var viewport

        class Selector: SelectorBase {
            override var configs: SelectorConfigs { .syncNotify }
            @Selected({ global.selectionBounds }) var bounds
            @Selected({ global.activeSymbol.symbolToWorld }) var symbolToWorld
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
            let transform = selector.symbolToWorld.concatenating(viewport.worldToView),
                bounds = bounds.applying(transform).outset(by: ActiveItemService.selectionBoundsOutset)
            menu.contextMenu(bounds: bounds)
        }
    }

    @ViewBuilder var menu: some View {
        HStack {
            Button { global.onZoom() } label: { Image(systemName: "arrow.up.left.and.arrow.down.right.square") }
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
            Button { global.onGroup() } label: { Image(systemName: "square.on.square.squareshape.controlhandles") }
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
            Button(role: .destructive) { global.onDelete() } label: { Image(systemName: "trash") }
                .frame(minWidth: 32)
        }
    }
}
