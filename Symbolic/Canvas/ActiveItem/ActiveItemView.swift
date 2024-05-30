import SwiftUI

private var activePathsSelector: [Path] {
    global.activeItem.store.activeItemIds
        .compactMap { global.path.path(id: $0) }
}

private var activeGroupsSelector: [ItemGroup] {
    global.activeItem.store.activeItemIds
        .compactMap { global.item.group(id: $0) }
}

// MARK: - ActiveItemView

struct ActiveItemView: View {
    var body: some View {
        ForEach(activeGroups) {
            GroupBounds(group: $0, viewport: viewport)
        }
        ForEach(activePaths) {
            PathBounds(path: $0, viewport: viewport)
        }
        SelectionBounds()
    }

    @Selected private var viewport = global.viewport.info
    @Selected private var activePaths = activePathsSelector
    @Selected private var activeGroups = activeGroupsSelector
}

// MARK: - GroupBounds

extension ActiveItemView {
    struct GroupBounds: View {
        let group: ItemGroup
        let viewport: ViewportInfo

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
            _focused = .init { global.activeItem.focusedItemId == group.id }
            _selected = .init { global.activeItem.selectedItemIds.contains(group.id) }
        }

        // MARK: private

        @Selected private var groupedPaths: [Path]
        @Selected private var focused: Bool
        @Selected private var selected: Bool

        private var toView: CGAffineTransform { viewport.worldToView }

        private var bounds: CGRect? {
            .init(union: groupedPaths.map { $0.boundingRect })?
                .applying(toView)
                .insetBy(dx: -4, dy: -4)
        }

        private func updateDrag(_ v: DragGesture.Value, pending: Bool = false) {
            let targetIds = (selected ? global.activeItem.selectedPaths : groupedPaths).map { $0.id }
            global.documentUpdater.updateInView(path: .move(.init(pathIds: targetIds, offset: v.offset)), pending: pending)
        }

        @ViewBuilder private var boundsRect: some View {
            if let bounds {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.blue.opacity(selected ? 0.1 : 0.03))
                    .stroke(.blue.opacity(focused ? 0.8 : selected ? 0.5 : 0.3), style: .init(lineWidth: 2))
                    .framePosition(rect: bounds)
                    .multipleGesture(.init(
                        onTouchDown: {
                            global.canvasAction.start(continuous: .moveSelection)
                        },
                        onTouchUp: {
                            global.canvasAction.end(continuous: .moveSelection)
                        },
                        onTap: { v, _ in
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
                                        let activeDescendants = global.item.expandedItems(rootItemId: group.id)
                                            .filter { $0.id != group.id && global.activeItem.store.activeItemIds.contains($0.id) }
                                        global.activeItem.selectRemove(itemIds: activeDescendants.map { $0.id })
                                    }
                                } else {
                                    global.activeItem.focus(itemId: group.id)
                                }
                            }
                        },
                        onDrag: { v, _ in updateDrag(v, pending: true) },
                        onDragEnd: { v, _ in updateDrag(v) }
                    ))
            }
        }
    }
}

// MARK: - PathBounds

extension ActiveItemView {
    struct PathBounds: View {
        let path: Path
        let viewport: ViewportInfo

        var body: some View {
            boundsRect
        }

        init(path: Path, viewport: ViewportInfo) {
            self.path = path
            self.viewport = viewport
            _focused = .init { global.activeItem.focusedItemId == path.id }
            _selected = .init { global.activeItem.selectedItemIds.contains(path.id) }
        }

        // MARK: private

        @Selected private var focused: Bool
        @Selected private var selected: Bool

        private var toView: CGAffineTransform { viewport.worldToView }

        private var bounds: CGRect {
            path.boundingRect.applying(toView)
        }

        private func updateDrag(_ v: DragGesture.Value, pending: Bool = false) {
            let targetIds = selected ? global.activeItem.selectedPaths.map { $0.id } : [path.id]
            global.documentUpdater.updateInView(path: .move(.init(pathIds: targetIds, offset: v.offset)), pending: pending)
        }

        @ViewBuilder private var boundsRect: some View {
            RoundedRectangle(cornerRadius: 2)
                .fill(.blue.opacity(focused ? 0.2 : 0.1))
                .stroke(.blue.opacity(focused ? 0.8 : 0.5))
                .framePosition(rect: bounds)
                .multipleGesture(.init(
                    onTouchDown: {
                        global.canvasAction.start(continuous: .moveSelection)
                    },
                    onTouchUp: {
                        global.canvasAction.end(continuous: .moveSelection)
                    },
                    onTap: { _, _ in
                        if global.toolbar.multiSelect {
                            global.activeItem.selectRemove(itemIds: [path.id])
                        } else {
                            global.activeItem.focus(itemId: path.id)
                        }
                    },
                    onDrag: { v, _ in updateDrag(v, pending: true) },
                    onDragEnd: { v, _ in updateDrag(v) }
                ))
        }
    }
}

private var selectedItemsSelector: [Item] {
    global.activeItem.selectedItemIds.compactMap { global.item.item(id: $0) }
}

private var selectionBoundsSelector: CGRect? {
    CGRect(union: selectedItemsSelector.compactMap { global.item.boundingRect(item: $0) })?.outset(by: 8)
}

// MARK: - SelectionBounds

extension ActiveItemView {
    struct SelectionBounds: View {
        var body: some View {
            boundsRect
        }

        @Selected private var selectedItems = selectedItemsSelector
        @Selected private var selectionBounds = selectionBoundsSelector
        @Selected private var toView = global.viewport.toView
        @Selected private var viewSize = global.viewport.store.viewSize

        @State private var dashPhase: CGFloat = 0
        @State private var menuSize: CGSize = .zero

        private var bounds: CGRect? { selectionBounds?.applying(toView) }

        @ViewBuilder private var boundsRect: some View {
            if let bounds {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.blue.opacity(0.5), style: .init(lineWidth: 2, dash: [8], dashPhase: dashPhase))
                    .framePosition(rect: bounds)
                    .modifier(AnimatedValue(value: $dashPhase, from: 0, to: 16, animation: .linear(duration: 0.4).repeatForever(autoreverses: false)))

                let menuAlign: PlaneOuterAlign = bounds.midY > CGRect(viewSize).midY ? .topCenter : .bottomCenter
                let menuBox = bounds.alignedBox(at: menuAlign, size: menuSize, gap: 8).clamped(by: CGRect(viewSize).insetBy(dx: 12, dy: 12))
                ContextMenu(onDelete: {
                    //                global.documentUpdater.update(path: .delete(.init(pathIds: selectedPathIds)))
                }, onGroup: {
                    global.documentUpdater.update(item: .group(.init(group: .init(id: UUID(), members: selectedItems.map { $0.id }), inGroupId: nil)))
                })
                .viewSizeReader { menuSize = $0 }
                .position(menuBox.center)
            }
        }
    }
}
