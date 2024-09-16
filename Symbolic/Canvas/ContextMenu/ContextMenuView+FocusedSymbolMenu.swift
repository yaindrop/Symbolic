import SwiftUI

// MARK: - global actions

private extension GlobalStores {
    var bounds: CGRect? { activeSymbol.focusedSymbolBounds }

    func onZoom() {
        guard let bounds else { return }
        viewportUpdater.zoomTo(worldRect: bounds)
    }

    func onLock() {
        guard let item = activeSymbol.focusedSymbolItem else { return }
        documentUpdater.update(item: .setLocked(.init(itemIds: [item.id], locked: !item.locked)))
    }

    func onDelete() {
//        guard let symbolId = activeSymbol.focusedSymbolId else { return }
//        documentUpdater.update(symbol: .delete(.init(symbolIds: [symbolId])))
    }
}

// MARK: - FocusedGroupMenu

extension ContextMenuView {
    struct FocusedSymbolMenu: View, TracedView, SelectorHolder {
        @Environment(\.sizedViewport) var viewport

        class Selector: SelectorBase {
            override var configs: SelectorConfigs { .syncNotify }
            @Selected({ global.bounds }) var bounds
            @Selected({ global.activeSymbol.focusedSymbolItem?.locked == true }) var locked
            @Selected({ global.activeSymbol.editingSymbol == nil }) var visible
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

extension ContextMenuView.FocusedSymbolMenu {
    @ViewBuilder var content: some View {
        if let bounds = selector.bounds, selector.visible {
            let bounds = bounds.applying(viewport.worldToView)
            menu.contextMenu(bounds: bounds)
        }
    }

    @ViewBuilder var menu: some View {
        HStack {
            ContextMenuView.ZoomButton { global.onZoom() }
            Divider()
            ContextMenuView.RenameButton {}
            ContextMenuView.LockButton(locked: selector.locked) { global.onLock() }
            Divider()
            ContextMenuView.CopyMenu {} cutAction: {} duplicateAction: {}
            ContextMenuView.DeleteButton { global.onDelete() }
        }
    }
}
