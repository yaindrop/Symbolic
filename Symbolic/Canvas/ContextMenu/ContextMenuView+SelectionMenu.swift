import SwiftUI

// MARK: - global actions

private extension GlobalStores {
    var bounds: CGRect? { activeItem.selectionBounds }

    func onZoom() {
        guard let bounds else { return }
        viewportUpdater.zoomTo(rect: bounds)
    }

    func onLock() {
        let itemIds = activeItem.selectedItemIds
        documentUpdater.update(item: .setLocked(.init(itemIds: .init(itemIds), locked: !activeItem.selectionLocked)))
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
            @Selected({ global.bounds }) var bounds
            @Selected({ global.activeSymbol.symbolToWorld }) var symbolToWorld
            @Selected({ global.activeItem.selectionLocked }) var locked
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
            ContextMenuView.ZoomButton { global.onZoom() }
            Divider()
            ContextMenuView.LockButton(locked: selector.locked) { global.onLock() }
            Menu {
                Button("Front", systemImage: "square.3.layers.3d.top.filled") {}
                Button("Move above") {}
                Button("Move below") {}
                Button("Back", systemImage: "square.3.layers.3d.bottom.filled") {}
            } label: { Image(systemName: "square.3.layers.3d") }
                .menuOrder(.fixed)
                .frame(minWidth: 32)
                .tint(.label)
            ContextMenuView.GroupButton(grouped: false) { global.onGroup() }
            Divider()
            ContextMenuView.CopyMenu {} cutAction: {} duplicateAction: {}
            ContextMenuView.DeleteButton { global.onDelete() }
        }
    }
}
