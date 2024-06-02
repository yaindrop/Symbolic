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
            if focused {
                global.contextMenu.representative(.group(.init(groupId: group.id)))
            }
        }

        init(group: ItemGroup, viewport: ViewportInfo) {
            self.group = group
            self.viewport = viewport
            _focused = .init { global.activeItem.focusedItemId == group.id }
            _selected = .init { global.activeItem.selectedItemIds.contains(group.id) }
            _bounds = .init { global.activeItem.boundingRect(itemId: group.id) }
        }

        // MARK: private

        @Selected private var focused: Bool
        @Selected private var selected: Bool
        @Selected private var bounds: CGRect?

        private var toView: CGAffineTransform { viewport.worldToView }

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
                            global.activeItem.onTap(group: group, position: $0.location)
                        },
                        onDrag: { updateDrag($0, pending: true) },
                        onDragEnd: { updateDrag($0) }
                    ))
            }
        }

        private func updateDrag(_ v: DragGesture.Value, pending: Bool = false) {
            if selected {
                let selectedPathIds = global.activeItem.selectedPaths.map { $0.id }
                global.documentUpdater.updateInView(path: .move(.init(pathIds: selectedPathIds, offset: v.offset)), pending: pending)
            } else {
                let groupedPathIds = global.item.groupedPaths(groupId: group.id).map { $0.id }
                global.documentUpdater.updateInView(path: .move(.init(pathIds: groupedPathIds, offset: v.offset)), pending: pending)
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
            if focused {
                global.contextMenu.representative(.path(.init(pathId: path.id)))
            }
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
                    onTap: { _ in global.activeItem.onTap(pathId: path.id) },
                    onDrag: { updateDrag($0, pending: true) },
                    onDragEnd: { updateDrag($0) }
                ))
                .framePosition(rect: bounds)
        }

        private func updateDrag(_ v: PanInfo, pending: Bool = false) {
            if selected {
                let selectedPathIds = global.activeItem.selectedPaths.map { $0.id }
                global.documentUpdater.updateInView(path: .move(.init(pathIds: selectedPathIds, offset: v.offset)), pending: pending)
            } else {
                global.documentUpdater.updateInView(activePath: .move(.init(offset: v.offset)), pending: pending)
            }
        }
    }
}

// MARK: - SelectionBounds

extension ActiveItemView {
    struct SelectionBounds: View {
        var body: some View {
            boundsRect
        }

        @Selected private var bounds = global.activeItem.selectionBounds

        @State private var dashPhase: CGFloat = 0

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
