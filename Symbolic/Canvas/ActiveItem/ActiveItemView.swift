import SwiftUI

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
    @Selected private var activePaths = global.activeItem.activePaths
    @Selected private var activeGroups = global.activeItem.activeGroups
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
            _activeDescendants = .init {
                global.item.expandedItems(rootItemId: group.id)
                    .filter { $0.id != group.id && global.activeItem.store.activeItemIds.contains($0.id) }
            }
        }

        // MARK: private

        @Selected private var groupedPaths: [Path]
        @Selected private var focused: Bool
        @Selected private var selected: Bool
        @Selected private var activeDescendants: [Item]

        private var toView: CGAffineTransform { viewport.worldToView }

        private var bounds: CGRect? {
            var outsetLevel = 1
            let minHeight = activeDescendants.map { global.item.height(itemId: $0.id) }.filter { $0 > 0 }.min()
            if let minHeight {
                let height = global.item.height(itemId: group.id)
                outsetLevel += height - minHeight
            }
            return .init(union: groupedPaths.map { $0.boundingRect })?
                .applying(toView)
                .outset(by: 6 * Scalar(outsetLevel))
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
                        onPress: {
                            global.canvasAction.start(continuous: .moveSelection)
                        },
                        onPressEnd: { cancelled in
                            global.canvasAction.end(continuous: .moveSelection)
                            if cancelled {
                                global.documentUpdater.cancel()
                            }
                        },

                        onTap: {
                            let worldPosition = $0.location.applying(global.viewport.toWorld)
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
                        onDrag: { updateDrag($0, pending: true) },
                        onDragEnd: { updateDrag($0) }
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

        private func updateDrag(_ v: PanInfo, pending: Bool = false) {
            let targetIds = selected ? global.activeItem.selectedPaths.map { $0.id } : [path.id]
            global.documentUpdater.updateInView(path: .move(.init(pathIds: targetIds, offset: v.offset)), pending: pending)
        }

        @ViewBuilder private var boundsRect: some View {
            RoundedRectangle(cornerRadius: 2)
                .fill(.blue.opacity(focused ? 0.2 : 0.1))
                .stroke(.blue.opacity(focused ? 0.8 : 0.5))
                .multipleTouchGesture(.init(
                    onPress: {
                        global.canvasAction.start(continuous: .moveSelection)
                    },
                    onPressEnd: { cancelled in
                        global.canvasAction.end(continuous: .moveSelection)
                        if cancelled { global.documentUpdater.cancel() }
                    },
                    onTap: { _ in
                        if global.toolbar.multiSelect {
                            global.activeItem.selectRemove(itemIds: [path.id])
                        } else {
                            global.activeItem.focus(itemId: path.id)
                        }
                    },
                    onDrag: { updateDrag($0, pending: true) },
                    onDragEnd: { updateDrag($0) }
                ))
                .framePosition(rect: bounds)
        }
    }
}

// MARK: - SelectionBounds

extension ActiveItemView {
    struct SelectionBounds: View {
        var body: some View {
            boundsRect
        }

        @Selected private var selectedItems = global.activeItem.selectedItems
        @Selected private var bounds = global.activeItem.selectionBounds
        @Selected private var viewSize = global.viewport.store.viewSize

        @State private var dashPhase: CGFloat = 0
        @State private var menuSize: CGSize = .zero

        @ViewBuilder private var boundsRect: some View {
            if let bounds {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.blue.opacity(0.5), style: .init(lineWidth: 2, dash: [8], dashPhase: dashPhase))
                    .framePosition(rect: bounds)
                    .modifier(AnimatedValue(value: $dashPhase, from: 0, to: 16, animation: .linear(duration: 0.4).repeatForever(autoreverses: false)))
                global.contextMenu.representative(.selection(.init()))
            }
        }
    }
}
