import SwiftUI

// MARK: - FocusedGroupMenu

extension ContextMenuView {
    struct FocusedGroupMenu: View, TracedView, SelectorHolder {
        class Selector: SelectorBase {
            override var configs: SelectorConfigs { .init(syncNotify: true) }
            @Selected({ global.viewport.sizedInfo }) var viewport
            @Selected({ global.activeItem.focusedGroup.map { global.item.boundingRect(itemId: $0.id) } }) var bounds
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
            AnimatableReader(selector.viewport) {
                menu.contextMenu(bounds: bounds.applying($0.worldToView).outset(by: selector.outset))
            }
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

            Divider()

            Button {} label: { Image(systemName: "lock") }
                .frame(minWidth: 32)
                .tint(.label)
            Menu { layerMenu } label: { Image(systemName: "square.3.layers.3d") }
                .menuOrder(.fixed)
                .frame(minWidth: 32)
                .tint(.label)
            Button { onUngroup() } label: { Image(systemName: "rectangle.3.group") }
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

    func onUngroup() {
        if let group = global.activeItem.focusedGroup {
            global.documentUpdater.update(item: .ungroup(.init(groupIds: [group.id])))
            global.activeItem.select(itemIds: group.members)
        }
    }

    func onDelete() {}
}
