import SwiftUI

// MARK: - global actions

private extension GlobalStore {
    func onTap(group: ItemGroup, position: Point2) {
        let worldPosition = position.applying(viewport.toWorld)
        let groupedPaths = item.groupedPaths(groupId: group.id)
        let path = groupedPaths.first {
            self.path.hitTest(path: $0, position: worldPosition, threshold: 32)
        }
        if let path {
            if toolbar.multiSelect {
                activeItem.selectAdd(itemId: path.id)
            } else {
                activeItem.focus(itemId: path.id)
            }
        } else {
            if toolbar.multiSelect {
                if activeItem.selected(itemId: group.id) {
                    activeItem.selectRemove(itemIds: [group.id])
                } else {
                    let activeDescendants = item.expandedItems(rootItemId: group.id)
                        .filter { $0.id != group.id && activeItem.activeItemIds.contains($0.id) }
                    activeItem.selectRemove(itemIds: activeDescendants.map { $0.id })
                }
            } else {
                activeItem.focus(itemId: group.id)
            }
        }
    }
}

// MARK: - GroupBounds

extension ActiveItemView {
    struct GroupBounds: View, TracedView, ComputedSelectorHolder {
        struct SelectorProps: Equatable { let groupId: UUID }
        class Selector: SelectorBase {
            override var syncUpdate: Bool { true }
            @Selected({ global.activeItem.focusedItemId == $0.groupId }) var focused
            @Selected({ global.activeItem.selectedItemIds.contains($0.groupId) }) var selected
            @Selected({ global.activeItem.boundingRect(itemId: $0.groupId) }) var bounds
        }

        @SelectorWrapper var selector

        let group: ItemGroup

        var body: some View { trace {
            setupSelector(.init(groupId: group.id)) {
                boundsRect
            }
        } }

        // MARK: private

        @ViewBuilder private var boundsRect: some View {
            if let bounds = selector.bounds {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.blue.opacity(selector.selected ? 0.1 : 0.03))
                    .stroke(.blue.opacity(selector.focused ? 0.8 : selector.selected ? 0.5 : 0.3), style: .init(lineWidth: 2))
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

                        onTap: { global.onTap(group: group, position: $0.location) },
                        onDrag: { updateDrag($0, pending: true) },
                        onDragEnd: { updateDrag($0) }
                    ))
            }
        }

        private func updateDrag(_ v: DragGesture.Value, pending: Bool = false) {
            if selector.selected {
                let selectedPathIds = global.activeItem.selectedPaths.map { $0.id }
                global.documentUpdater.updateInView(path: .move(.init(pathIds: selectedPathIds, offset: v.offset)), pending: pending)
            } else {
                let groupedPathIds = global.item.groupedPaths(groupId: group.id).map { $0.id }
                global.documentUpdater.updateInView(path: .move(.init(pathIds: groupedPathIds, offset: v.offset)), pending: pending)
            }
        }
    }
}
