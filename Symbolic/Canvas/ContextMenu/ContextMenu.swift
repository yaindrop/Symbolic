import Foundation
import SwiftUI

enum ContextMenuData: HashIdentifiable {
    case pathNode
    case focusedPath
    case focusedGroup
    case selection
}

class ContextMenuStore: Store {
    @Trackable var menus = Set<ContextMenuData>()

    func register(_ data: ContextMenuData) {
        update { $0(\._menus, menus.with { $0.insert(data) }) }
    }

    func deregister(_ data: ContextMenuData) {
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
    @Selected private var menus = global.contextMenu.menus

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

    var body: some View {
        wrapper
    }

    @Selected private var viewSize = global.viewport.store.viewSize
    @Selected private var focusedPath = global.activeItem.activePath
    @Selected private var focusedGroup = global.activeItem.focusedGroup
    @Selected private var bounds: CGRect?

    @State private var prevBounds: CGRect = .zero
    @State private var size: CGSize = .zero

    @ViewBuilder var wrapper: some View {
        let bounds = bounds ?? prevBounds
        let menuAlign: PlaneOuterAlign = bounds.midY > CGRect(viewSize).midY ? .topCenter : .bottomCenter
        let menuBox = bounds.alignedBox(at: menuAlign, size: size, gap: .init(squared: 12)).clamped(by: CGRect(viewSize).inset(by: 12))
        menu
            .padding(12)
            .background(.regularMaterial)
            .fixedSize()
            .sizeReader { size = $0 }
            .clipRounded(radius: size.height / 2)
            .position(menuBox.center)
            .onChange(of: self.bounds) { prevBounds = self.bounds ?? prevBounds }
    }

    @ViewBuilder var menu: some View {
        switch data {
        case .pathNode: EmptyView()
        case .focusedPath:
            if let focusedPath {
                PathMenu(bounds: $bounds, path: focusedPath)
            }
        case .focusedGroup:
            if let focusedGroup {
                GroupMenu(bounds: $bounds, group: focusedGroup)
            }
        case .selection:
            SelectionMenu(bounds: $bounds)
        }
    }
}

// MARK: - GroupMenu

extension ContextMenu {
    struct PathMenu: View {
        let path: Path

        var body: some View {
            if let bounds {
                menu.preference(key: MenuAlignBoundsKey.self, value: bounds)
            }
        }

        init(bounds: Reselected<CGRect?>, path: Path) {
            self.path = path
            _bounds = bounds
            _bounds.reselect { global.activeItem.boundingRect(itemId: path.id) }
        }

        // MARK: private

        @Reselected private var bounds: CGRect?

        @ViewBuilder private var menu: some View {
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
        let group: ItemGroup

        var body: some View {
            if let bounds {
                menu.preference(key: MenuAlignBoundsKey.self, value: bounds)
            }
        }

        init(bounds: Reselected<CGRect?>, group: ItemGroup) {
            self.group = group
            _bounds = bounds
            _bounds.reselect { global.activeItem.boundingRect(itemId: group.id) }
        }

        // MARK: private

        @Reselected private var bounds: CGRect?

        @ViewBuilder private var menu: some View {
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
            global.documentUpdater.update(item: .ungroup(.init(groupIds: [group.id])))
            global.activeItem.select(itemIds: group.members)
        }

        private func onDelete() {}
    }
}

// MARK: - SelectionMenu

extension ContextMenu {
    struct SelectionMenu: View {
        var body: some View {
            if let bounds {
                menu.preference(key: MenuAlignBoundsKey.self, value: bounds)
            }
        }

        init(bounds: Reselected<CGRect?>) {
            _bounds = bounds
            _bounds.reselect { global.activeItem.selectionBounds }
        }

        // MARK: private

        @Reselected private var bounds: CGRect?

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
