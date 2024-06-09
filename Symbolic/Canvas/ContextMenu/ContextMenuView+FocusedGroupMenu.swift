import SwiftUI

// MARK: - FocusedGroupMenu

extension ContextMenuView {
    struct FocusedGroupMenu: View, TracedView, SelectorHolder {
        class Selector: SelectorBase {
            override var syncUpdate: Bool { true }
            @Selected({ global.activeItem.focusedGroupBounds }) var bounds
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
            menu.contextMenu(bounds: bounds)
        }
    }

    @ViewBuilder var menu: some View {
        HStack {
            Button {} label: { Image(systemName: "arrow.up.left.and.arrow.down.right") }
                .frame(minWidth: 32)
                .tint(.label)

            Divider()

            Button {} label: { Image(systemName: "lock") }
                .frame(minWidth: 32)
                .tint(.label)
            Menu {
                Button("Front", systemImage: "square.3.layers.3d.top.filled") {}
                Button("Move above") {}
                Button("Move below") {}
                Button("Back", systemImage: "square.3.layers.3d.bottom.filled") {}
            } label: { Image(systemName: "square.3.layers.3d") }
                .frame(minWidth: 32)
                .menuOrder(.fixed)
                .tint(.label)
            Button { onUngroup() } label: { Image(systemName: "rectangle.3.group") }
                .frame(minWidth: 32)
                .tint(.label)

            Divider()

            Menu {
                Button("Copy", systemImage: "doc.on.doc") {}
                Button("Cut", systemImage: "scissors") {}
                Button("Duplicate", systemImage: "plus.square.on.square") {}
            } label: { Image(systemName: "doc.on.doc") }
                .frame(minWidth: 32)
                .menuOrder(.fixed)
                .tint(.label)
            Button(role: .destructive) { onDelete() } label: { Image(systemName: "trash") }
                .frame(minWidth: 32)
        }
    }

    func onUngroup() {
        if let group = global.activeItem.focusedGroup {
            global.documentUpdater.update(item: .ungroup(.init(groupIds: [group.id])))
            global.activeItem.select(itemIds: group.members)
        }
    }

    func onDelete() {}
}
