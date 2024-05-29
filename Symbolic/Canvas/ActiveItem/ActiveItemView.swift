import SwiftUI

private var activePathsSelector: [Path] {
    global.activeItem.store.activeItemIds
        .compactMap { global.path.path(id: $0) }
}

private var activeGroupsSelector: [ItemGroup] {
    global.activeItem.store.activeItemIds
        .compactMap { global.item.group(id: $0) }
}

struct ActiveItemView: View {
    @Selected var viewport = global.viewport.info
    @Selected var viewSize = global.activeItem.store.activeItemIds
    @Selected var activePaths = activePathsSelector
    @Selected var activeGroups = activeGroupsSelector

    var body: some View {
        ForEach(activeGroups) {
            Group(group: $0, viewport: viewport)
        }
        ForEach(activePaths) {
            PathBounds(path: $0, viewport: viewport, groupedPaths: [])
        }
    }
}

extension ActiveItemView {
    struct Group: View {
        let group: ItemGroup
        let viewport: ViewportInfo

        var toView: CGAffineTransform { viewport.worldToView }

        var body: some View {
            boundsRect
        }

        init(group: ItemGroup, viewport: ViewportInfo) {
            self.group = group
            self.viewport = viewport
            _groupedPaths = .init {
                global.item.leafItems(rootItemId: group.id)
                    .compactMap { $0.pathId.map { global.path.path(id: $0) } }
            }
            _focused = .init {
                global.activeItem.store.focusedItemId == group.id
            }
            _activeDescendants = .init {
                global.item.expandedItems(rootItemId: group.id)
                    .filter { $0.id != group.id && global.activeItem.store.activeItemIds.contains($0.id) }
            }
        }

        @Selected private var groupedPaths: [Path]
        @Selected private var focused: Bool
        @Selected private var activeDescendants: [Item]

        private var selected: Bool { activeDescendants.isEmpty }

        private var bounds: CGRect? {
            .init(union: groupedPaths.map { $0.boundingRect })?
                .applying(toView)
                .insetBy(dx: -4, dy: -4)
        }

        @State private var gesture = MultipleGestureModel<Void>()

        @ViewBuilder private var boundsRect: some View {
            if let bounds {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.blue.opacity(selected ? 0.2 : 0.1))
                    .stroke(.blue.opacity(focused ? 0.8 : selected ? 0.5 : 0.3), style: .init(lineWidth: 2))
                    .frame(width: bounds.width, height: bounds.height)
                    .position(bounds.center)
                    .multipleGesture(gesture, ()) {
                        func update(pending: Bool = false) -> (DragGesture.Value, Void) -> Void {
                            { v, _ in global.documentUpdater.updateInView(path: .move(.init(pathIds: groupedPaths.map { $0.id }, offset: v.offset)), pending: pending) }
                        }
                        $0.onTap { v, _ in
                            let worldPosition = v.location.applying(global.viewport.toWorld)
                            let path = groupedPaths.first {
                                global.path.hitTest(path: $0, position: worldPosition, threshold: 32)
                            }
                            if let path {
                                if global.toolbar.multiSelect {
                                    global.activeItem.selectAdd(itemId: path.id)
                                } else {
                                    global.activeItem.focus(itemId: path.id)
                                }
                            } else {
                                if global.toolbar.multiSelect {
                                    if selected {
                                        global.activeItem.selectRemove(itemIds: [group.id])
                                    } else {
                                        global.activeItem.selectRemove(itemIds: activeDescendants.map { $0.id })
                                    }
                                } else {
                                    global.activeItem.focus(itemId: group.id)
                                }
                            }
                        }
                        $0.onDrag(update(pending: true))
                        $0.onDragEnd(update())
                        $0.onTouchDown {
                            global.canvasAction.start(continuous: .moveSelection)
                        }
                        $0.onTouchUp {
                            global.canvasAction.end(continuous: .moveSelection)
                        }
                    }
            }
        }
    }

    struct PathBounds: View {
        let path: Path
        let viewport: ViewportInfo
        let groupedPaths: [Path]

        var toView: CGAffineTransform { viewport.worldToView }

        @State private var gesture = MultipleGestureModel<Void>()

        init(path: Path, viewport: ViewportInfo, groupedPaths: [Path]) {
            self.path = path
            self.viewport = viewport
            self.groupedPaths = groupedPaths
        }

        var body: some View {
            let rect = path.boundingRect.applying(toView)
            RoundedRectangle(cornerRadius: 2)
                .fill(.blue.opacity(0.2))
                .stroke(.blue.opacity(0.5))
                .frame(width: rect.width, height: rect.height)
                .position(rect.center)
                .multipleGesture(gesture, ()) {
                    func update(pending: Bool = false) -> (DragGesture.Value, Void) -> Void {
                        { v, _ in global.documentUpdater.updateInView(path: .move(.init(pathIds: groupedPaths.map { $0.id }, offset: v.offset)), pending: pending) }
                    }
                    $0.onTap { _, _ in
                        if global.toolbar.multiSelect {
                            global.activeItem.selectRemove(itemIds: [path.id])
                        } else {
                            global.activeItem.focus(itemId: path.id)
                        }
                    }
                    $0.onDrag(update(pending: true))
                    $0.onDragEnd(update())
                    $0.onTouchDown {
                        global.canvasAction.start(continuous: .moveSelection)
                    }
                    $0.onTouchUp {
                        global.canvasAction.end(continuous: .moveSelection)
                    }
                }
        }
    }
}
