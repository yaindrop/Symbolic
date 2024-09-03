import SwiftUI

// MARK: - global actions

private extension GlobalStores {
    var bounds: CGRect? { activeItem.focusedPathBounds }

    func onZoom() {
        guard let bounds else { return }
        viewportUpdater.zoomTo(rect: bounds)
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
            Button { global.onZoom() } label: { Image(systemName: "arrow.up.left.and.arrow.down.right.square") }
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
