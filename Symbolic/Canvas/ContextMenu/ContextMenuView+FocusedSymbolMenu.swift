import SwiftUI

// MARK: - global actions

private extension GlobalStores {
    var focusedSymbolBounds: CGRect? { activeSymbol.focusedSymbol?.boundingRect }

    func onZoom() {
        guard let focusedSymbolBounds else { return }
        viewportUpdater.zoomTo(rect: focusedSymbolBounds)
    }

    func onDelete() {
        guard let symbolId = activeSymbol.focusedSymbolId else { return }
        documentUpdater.update(symbol: .delete(.init(symbolIds: [symbolId])))
    }
}

// MARK: - FocusedGroupMenu

extension ContextMenuView {
    struct FocusedSymbolMenu: View, TracedView, SelectorHolder {
        @Environment(\.sizedViewport) var viewport

        class Selector: SelectorBase {
            override var configs: SelectorConfigs { .syncNotify }
            @Selected({ global.focusedSymbolBounds }) var bounds
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
            Button { global.onZoom() } label: { Image(systemName: "arrow.up.left.and.arrow.down.right") }
                .frame(minWidth: 32)
                .tint(.label)

            Divider()

            Button {} label: { Image(systemName: "character.cursor.ibeam") }
                .frame(minWidth: 32)
                .tint(.label)
            Button {} label: { Image(systemName: "lock") }
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

    @ViewBuilder var copyMenu: some View {
        Button("Copy", systemImage: "doc.on.doc") {}
        Button("Cut", systemImage: "scissors") {}
        Button("Duplicate", systemImage: "plus.square.on.square") {}
    }
}
