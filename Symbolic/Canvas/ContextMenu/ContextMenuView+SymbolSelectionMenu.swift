import SwiftUI

// MARK: - global actions

private extension GlobalStores {
    var selectionBounds: CGRect? { activeSymbol.selectionBounds }

    func onZoom() {
        guard let selectionBounds else { return }
        viewportUpdater.zoomTo(rect: selectionBounds)
    }

    func onDelete() {
        let pathIds = activeItem.selectedItems.map { $0.id }
        documentUpdater.update(path: .delete(.init(pathIds: pathIds)))
        activeItem.blur()
    }
}

// MARK: - SymbolSelectionMenu

extension ContextMenuView {
    struct SymbolSelectionMenu: View, SelectorHolder {
        @Environment(\.sizedViewport) var viewport

        class Selector: SelectorBase {
            override var configs: SelectorConfigs { .syncNotify }
            @Selected({ global.selectionBounds }) var bounds
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
            Button { global.onZoom() } label: { Image(systemName: "arrow.up.left.and.arrow.down.right.square") }
                .frame(minWidth: 32)
                .tint(.label)

            Divider()

            Button {} label: { Image(systemName: "lock") }
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
