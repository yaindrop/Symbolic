import SwiftUI

// MARK: - global actions

private extension GlobalStores {
    var focusedGroupBounds: CGRect? { activeItem.focusedGroup.map { item.boundingRect(of: $0.id) } }

    func onZoom() {
        guard let focusedGroupBounds else { return }
        viewportUpdater.zoomTo(rect: focusedGroupBounds)
    }

    func onUngroup() {
        guard let group = activeItem.focusedGroup else { return }
        documentUpdater.update(item: .ungroup(.init(groupIds: [group.id])))
        activeItem.select(itemIds: group.members)
    }

    func onDelete() {
//        guard let pathId = activeItem.focusedPathId else { return }
//        documentUpdater.update(path: .delete(.init(pathIds: [pathId])))
    }
}

// MARK: - FocusedGroupMenu

extension ContextMenuView {
    struct FocusedGroupMenu: View, TracedView, SelectorHolder {
        @Environment(\.sizedViewport) var viewport

        class Selector: SelectorBase {
            override var configs: SelectorConfigs { .syncNotify }
            @Selected({ global.focusedGroupBounds }) var bounds
            @Selected({ global.activeSymbol.symbolToWorld }) var symbolToWorld
            @Selected({ global.activeItem.focusedGroup.map { global.activeItem.groupOutset(id: $0.id) } ?? 0 }) var outset
        }

        @SelectorWrapper var selector

        var body: some View { trace {
            setupSelector {
                content
            }
        } }
    }
}

// MARK: private

extension ContextMenuView.FocusedGroupMenu {
    @ViewBuilder var content: some View {
        if let bounds = selector.bounds {
            let transform = selector.symbolToWorld.concatenating(viewport.worldToView),
                bounds = bounds.applying(transform).outset(by: selector.outset)
            menu.contextMenu(bounds: bounds)
        }
    }

    @ViewBuilder var menu: some View {
        HStack {
            Button { global.onZoom() } label: { Image(systemName: "arrow.up.left.and.arrow.down.right") }
                .frame(minWidth: 32)
                .tint(.label)

            Divider()

            Button {} label: { Image(systemName: "lock") }
                .frame(minWidth: 32)
                .tint(.label)
            Menu { layerMenu } label: { Image(systemName: "square.3.layers.3d") }
                .menuOrder(.fixed)
                .frame(minWidth: 32)
                .tint(.label)
            Button { global.onUngroup() } label: { Image(systemName: "rectangle.3.group") }
                .frame(minWidth: 32)
                .tint(.label)

            Divider()

            Menu { copyMenu } label: { Image(systemName: "doc.on.doc") }
                .menuOrder(.fixed)
                .frame(minWidth: 32)
                .tint(.label)
            Button(role: .destructive) { global.onDelete() } label: { Image(systemName: "trash") }
                .frame(minWidth: 32)
        }
    }

    @ViewBuilder var layerMenu: some View {
        Button("Front", systemImage: "square.3.layers.3d.top.filled") {}
        Button("Move above") {}
        Button("Move below") {}
        Button("Back", systemImage: "square.3.layers.3d.bottom.filled") {}
    }

    @ViewBuilder var copyMenu: some View {
        Button("Copy", systemImage: "doc.on.doc") {}
        Button("Cut", systemImage: "scissors") {}
        Button("Duplicate", systemImage: "plus.square.on.square") {}
    }
}
