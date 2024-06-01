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

private struct MenuSizeKey: EnvironmentKey {
    typealias Value = CGSize
    static let defaultValue: Value = .zero
}

private extension EnvironmentValues {
    var menuSize: CGSize {
        get { self[MenuSizeKey.self] }
        set { self[MenuSizeKey.self] = newValue }
    }
}

private struct MenuPositionKey: PreferenceKey {
    typealias Value = Point2
    static var defaultValue: Value = .zero
    static func reduce(value: inout Value, nextValue: () -> Value) { value = nextValue() }
}

struct ContextMenu: View {
    let data: ContextMenuData

    @State private var size: CGSize = .zero
    @State private var position: Point2 = .zero

    var body: some View {
        Group {
            switch data {
            case let .pathNode(data): EmptyView()
            case let .path(data): EmptyView()
            case let .group(data): GroupMenu(data: data)
            case let .selection(data): SelectionMenu(data: data)
            }
        }
        .padding(12)
        .background(.thickMaterial)
        .fixedSize()
        .sizeReader { size = $0 }
        .cornerRadius(size.height / 2)
        .position(position)
        .environment(\.menuSize, size)
        .onPreferenceChange(MenuPositionKey.self) { position = $0 }
    }
}

extension ContextMenu {
    struct SelectionMenu: View {
        let data: ContextMenuData.Selection

        @Selected private var bounds = global.activeItem.selectionBounds
        @Selected private var viewSize = global.viewport.store.viewSize

        @Environment(\.menuSize) private var menuSize: CGSize

        var body: some View {
            if let bounds {
                let menuAlign: PlaneOuterAlign = bounds.midY > CGRect(viewSize).midY ? .topCenter : .bottomCenter
                let menuBox = bounds.alignedBox(at: menuAlign, size: menuSize, gap: 12).clamped(by: CGRect(viewSize).inset(by: 12))
                HStack {
                    Button { onGroup() } label: { Image(systemName: "rectangle.3.group") }
                    Divider()
                    Button(role: .destructive) { onDelete() } label: { Image(systemName: "trash") }
                }
                .preference(key: MenuPositionKey.self, value: menuBox.center)
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

extension ContextMenu {
    struct GroupMenu: View {
        let data: ContextMenuData.Group

        init(data: ContextMenuData.Group) {
            self.data = data
            _group = .init { global.item.group(id: data.groupId) }
            _bounds = .init { global.activeItem.boundingRect(itemId: data.groupId) }
        }

        @Selected private var group: ItemGroup?
        @Selected private var bounds: CGRect?
        @Selected private var viewSize = global.viewport.store.viewSize

        @Environment(\.menuSize) private var menuSize: CGSize

        var body: some View {
            if let bounds {
                let menuAlign: PlaneOuterAlign = bounds.midY > CGRect(viewSize).midY ? .topCenter : .bottomCenter
                let menuBox = bounds.alignedBox(at: menuAlign, size: menuSize, gap: 12).clamped(by: CGRect(viewSize).inset(by: 12))
                HStack {
                    Button { onUngroup() } label: { Image(systemName: "rectangle.slash") }
                    Divider()
                    Button(role: .destructive) { onDelete() } label: { Image(systemName: "trash") }
                }
                .preference(key: MenuPositionKey.self, value: menuBox.center)
            }
        }

        private func onUngroup() {
            global.documentUpdater.update(item: .ungroup(.init(groupIds: [data.groupId])))
        }

        private func onDelete() {}
    }
}
