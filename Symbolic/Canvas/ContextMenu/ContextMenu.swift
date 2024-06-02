import Foundation
import SwiftUI

enum ContextMenuData: HashIdentifiable {
    struct PathNode: HashIdentifiable {
        let pathId: UUID, nodeId: UUID
    }

    struct Path: HashIdentifiable {
        let pathId: UUID
    }

    struct Group: HashIdentifiable {
        let groupId: UUID
    }

    struct Selection: HashIdentifiable {}

    case pathNode(PathNode)
    case path(Path)
    case group(Group)
    case selection(Selection)
}

class ContextMenuStore: Store {
    @Trackable var menus = Set<ContextMenuData>()

    fileprivate func register(_ data: ContextMenuData) {
        update { $0(\._menus, menus.with { $0.insert(data) }) }
    }

    fileprivate func deregister(_ data: ContextMenuData) {
        update { $0(\._menus, menus.with { $0.remove(data) }) }
    }

    @ViewBuilder func representative(_ data: ContextMenuData) -> some View {
        Color.clear
            .onAppear { self.register(data) }
            .onDisappear { self.deregister(data) }
            .onChange(of: data) {
                self.deregister($0)
                self.register($1)
            }
    }
}

struct ContextMenuRoot: View {
    @Selected var menus = global.contextMenu.menus

    var body: some View {
        ZStack {
            ForEach(Array(menus)) { ContextMenu(data: $0) }
        }
    }
}

private struct MenuAlignBoundsKey: PreferenceKey {
    typealias Value = CGRect
    static var defaultValue: Value = .zero
    static func reduce(value: inout Value, nextValue: () -> Value) { value = nextValue() }
}

struct ContextMenu: View {
    let data: ContextMenuData

    @Selected private var viewSize = global.viewport.store.viewSize

    @State private var size: CGSize = .zero
    @State private var bounds: CGRect = .zero

    var body: some View {
        let menuAlign: PlaneOuterAlign = bounds.midY > CGRect(viewSize).midY ? .topCenter : .bottomCenter
        let menuBox = bounds.alignedBox(at: menuAlign, size: size, gap: 12).clamped(by: CGRect(viewSize).inset(by: 12))
        Group {
            switch data {
            case let .pathNode(data): EmptyView()
            case let .path(data): PathMenu(data: data)
            case let .group(data): GroupMenu(data: data)
            case let .selection(data): SelectionMenu(data: data)
            }
        }
        .padding(12)
        .background(.regularMaterial)
        .fixedSize()
        .sizeReader { size = $0 }
        .clipRounded(radius: size.height / 2)
        .position(menuBox.center)
        .onPreferenceChange(MenuAlignBoundsKey.self) { bounds = $0 }
    }
}

// MARK: - GroupMenu

extension ContextMenu {
    struct PathMenu: View {
        let data: ContextMenuData.Path

        var body: some View {
            if let bounds {
                menu.preference(key: MenuAlignBoundsKey.self, value: bounds)
            }
        }

        init(data: ContextMenuData.Path) {
            self.data = data
            _path = .init { global.path.path(id: data.pathId) }
            _bounds = .init { global.activeItem.boundingRect(itemId: data.pathId) }
        }

        // MARK: private

        @Selected private var path: Path?
        @Selected private var bounds: CGRect?

        private var menu: some View {
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

        private func onUngroup() {}

        private func onDelete() {}
    }
}

// MARK: - GroupMenu

extension ContextMenu {
    struct GroupMenu: View {
        let data: ContextMenuData.Group

        var body: some View {
            if let bounds {
                menu.preference(key: MenuAlignBoundsKey.self, value: bounds)
            }
        }

        init(data: ContextMenuData.Group) {
            self.data = data
            _group = .init { global.item.group(id: data.groupId) }
            _bounds = .init { global.activeItem.boundingRect(itemId: data.groupId) }
        }

        // MARK: private

        @Selected private var group: ItemGroup?
        @Selected private var bounds: CGRect?

        private var menu: some View {
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

        private func onUngroup() {
            if let group {
                global.documentUpdater.update(item: .ungroup(.init(groupIds: [group.id])))
                global.activeItem.select(itemIds: group.members)
            }
        }

        private func onDelete() {}
    }
}

// MARK: - SelectionMenu

extension ContextMenu {
    struct SelectionMenu: View {
        let data: ContextMenuData.Selection

        var body: some View {
            if let bounds {
                menu.preference(key: MenuAlignBoundsKey.self, value: bounds)
            }
        }

        // MARK: private

        @Selected private var bounds = global.activeItem.selectionBounds

        var menu: some View {
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
                Button { onGroup() } label: { Image(systemName: "square.on.square.squareshape.controlhandles") }
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

        private func onGroup() {
            global.documentUpdater.groupSelection()
        }

        private func onDelete() {
            global.documentUpdater.deleteSelection()
        }
    }
}
