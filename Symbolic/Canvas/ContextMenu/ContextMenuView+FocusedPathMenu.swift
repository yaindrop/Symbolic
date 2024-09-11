import SwiftUI

// MARK: - global actions

private extension GlobalStores {
    var bounds: CGRect? { activeItem.focusedPathBounds }

    func onZoom() {
        guard let bounds else { return }
        viewportUpdater.zoomTo(worldRect: bounds.applying(activeSymbol.symbolToWorld))
    }

    func onLock() {
        guard let item = activeItem.focusedPathItem else { return }
        documentUpdater.update(item: .setLocked(.init(itemIds: [item.id], locked: !item.locked)))
    }

    func onDelete() {
        guard let pathId = activeItem.focusedPathId else { return }
        documentUpdater.update(path: .delete(.init(pathIds: [pathId])))
    }
}

// MARK: - FocusedPathMenu

extension ContextMenuView {
    struct FocusedPathMenu: View, TracedView, SelectorHolder {
        @Environment(\.sizedViewport) var viewport

        class Selector: SelectorBase {
            override var configs: SelectorConfigs { .syncNotify }
            @Selected({ global.bounds }) var bounds
            @Selected({ global.focusedPath.selectingNodes }) var selectingNodes
            @Selected({ global.focusedPath.activeNodeIds.isEmpty }) var visible
            @Selected({ global.activeSymbol.symbolToWorld }) var symbolToWorld
            @Selected({ global.activeItem.focusedPathItem?.locked ?? false }) var locked
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

extension ContextMenuView.FocusedPathMenu {
    @ViewBuilder var content: some View {
        if let bounds = selector.bounds, selector.visible {
            let transform = selector.symbolToWorld.concatenating(viewport.worldToView),
                bounds = bounds.applying(transform)
            menu.contextMenu(bounds: bounds)
        }
    }

    @ViewBuilder var menu: some View {
        HStack {
            ContextMenuView.ZoomButton { global.onZoom() }
            ContextMenuView.SelectButton(selecting: selector.selectingNodes) {
                global.focusedPath.setSelecting(!selector.selectingNodes)
            }
            Divider()

            ContextMenuView.LockButton(locked: selector.locked) { global.onLock() }
            Menu { layerMenu } label: { Image(systemName: "square.3.layers.3d") }
                .menuOrder(.fixed)
                .frame(minWidth: 32)
                .tint(.label)
            Divider()
            ContextMenuView.CopyMenu {} cutAction: {} duplicateAction: {}
            ContextMenuView.DeleteButton { global.onDelete() }
        }
    }

    @ViewBuilder var layerMenu: some View {
        Button("Front", systemImage: "square.3.layers.3d.top.filled") {}
        Button("Move above") {}
        Button("Move below") {}
        Button("Back", systemImage: "square.3.layers.3d.bottom.filled") {}
    }
}
