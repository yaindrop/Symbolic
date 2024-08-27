import SwiftUI

// MARK: - FocusedPathMenu

extension ContextMenuView {
    struct FocusedPathMenu: View, TracedView, SelectorHolder {
        @Environment(\.sizedViewport) var viewport

        class Selector: SelectorBase {
            override var configs: SelectorConfigs { .init(syncNotify: true) }
            @Selected({ global.activeSymbol.symbolToWorld }) var symbolToWorld
            @Selected({ global.activeItem.focusedPathId.map { global.item.boundingRect(itemId: $0) } }) var bounds
            @Selected({ global.focusedPath.selectingNodes }) var selectingNodes
            @Selected({ global.focusedPath.activeNodeIds.isEmpty }) var visible
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
            Button {
                if let bounds = selector.bounds {
                    global.viewportUpdater.zoomTo(rect: bounds)
                }
            } label: { Image(systemName: "arrow.up.left.and.arrow.down.right") }
                .frame(minWidth: 32)
                .tint(.label)

            Button {
                global.focusedPath.setSelecting(!selector.selectingNodes)
            } label: { Image(systemName: "checklist").foregroundStyle(selector.selectingNodes ? .blue : .label) }
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

            Divider()

            Menu { copyMenu } label: { Image(systemName: "doc.on.doc") }
                .menuOrder(.fixed)
                .frame(minWidth: 32)
                .tint(.label)
            Button(role: .destructive) { onDelete() } label: { Image(systemName: "trash") }
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

    func onUngroup() {}

    func onDelete() {}
}
