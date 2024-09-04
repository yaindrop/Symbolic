import SwiftUI

// MARK: - global actions

private extension GlobalStores {
    var bounds: CGRect? { activeSymbol.selectionBounds }

    func onZoom() {
        guard let bounds else { return }
        viewportUpdater.zoomTo(rect: bounds)
    }

    func onLock() {
        let symbolIds = activeSymbol.selectedSymbolIds
        documentUpdater.update(item: .setLocked(.init(itemIds: .init(symbolIds), locked: !activeSymbol.selectionLocked)))
    }

    func onDelete() {
        let symbolIds = activeSymbol.selectedSymbolIds
        documentUpdater.update(symbol: .delete(.init(symbolIds: .init(symbolIds))))
        activeSymbol.select(symbolIds: [])
    }
}

// MARK: - SymbolSelectionMenu

extension ContextMenuView {
    struct SymbolSelectionMenu: View, SelectorHolder {
        @Environment(\.sizedViewport) var viewport

        class Selector: SelectorBase {
            override var configs: SelectorConfigs { .syncNotify }
            @Selected({ global.bounds }) var bounds
            @Selected({ global.activeSymbol.selectionLocked }) var locked
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

extension ContextMenuView.SymbolSelectionMenu {
    @ViewBuilder var content: some View {
        if let bounds = selector.bounds {
            let bounds = bounds.applying(viewport.worldToView).outset(by: ActiveSymbolService.selectionBoundsOutset)
            menu.contextMenu(bounds: bounds)
        }
    }

    @ViewBuilder var menu: some View {
        HStack {
            ContextMenuView.ZoomButton { global.onZoom() }
            Divider()
            ContextMenuView.LockButton(locked: selector.locked) { global.onLock() }
            Divider()
            ContextMenuView.CopyMenu {} cutAction: {} duplicateAction: {}
            ContextMenuView.DeleteButton { global.onDelete() }
        }
    }
}
