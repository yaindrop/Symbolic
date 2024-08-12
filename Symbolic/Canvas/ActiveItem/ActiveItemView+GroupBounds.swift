import SwiftUI

// MARK: - global actions

private extension GlobalStores {
    func onTap(group: ItemGroup, position: Point2) {
        let worldPosition = position.applying(viewport.toWorld)
        let groupedPathIds = item.groupedPathIds(groupId: group.id)
        let path = groupedPathIds.first {
            guard let p = self.path.get(id: $0) else { return false }
            return self.path.hitTest(path: p, position: worldPosition, threshold: 32)
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

    func onDrag(group: ItemGroup, _ v: PanInfo, pending: Bool = false) {
        let offset = v.offset.applying(viewport.toWorld)
        if activeItem.selected(itemId: group.id) {
            let pathIds = activeItem.selectedPathIds
            documentUpdater.update(path: .move(.init(pathIds: pathIds, offset: offset)), pending: pending)
        } else {
            let pathIds = item.groupedPathIds(groupId: group.id)
            documentUpdater.update(path: .move(.init(pathIds: pathIds, offset: offset)), pending: pending)
        }
    }

    func gesture(group: ItemGroup) -> MultipleTouchGesture {
        .init(
            onPress: {
                canvasAction.start(continuous: .moveSelection)
            },
            onPressEnd: { cancelled in
                canvasAction.end(continuous: .moveSelection)
                if cancelled {
                    documentUpdater.cancel()
                }
            },

            onTap: { onTap(group: group, position: $0.location) },
            onDrag: { onDrag(group: group, $0, pending: true) },
            onDragEnd: { onDrag(group: group, $0) },

            onPinch: { viewportUpdater.onPinch($0) },
            onPinchEnd: { _ in viewportUpdater.onCommit() }
        )
    }
}

// MARK: - GroupBounds

extension ActiveItemView {
    struct GroupBounds: View, TracedView, EquatableBy, ComputedSelectorHolder {
        let group: ItemGroup

        var equatableBy: some Equatable { group }

        struct SelectorProps: Equatable { let groupId: UUID }
        class Selector: SelectorBase {
            override var configs: SelectorConfigs { .init(syncNotify: true) }
            @Selected({ global.viewport.sizedInfo }) var viewport
            @Selected({ global.item.boundingRect(itemId: $0.groupId) }) var bounds
            @Selected({ global.activeItem.groupOutset(id: $0.groupId) }) var outset
            @Selected({ global.activeItem.focusedItemId == $0.groupId }) var focused
            @Selected({ global.activeItem.selectedItemIds.contains($0.groupId) }) var selected
        }

        @SelectorWrapper var selector

        var body: some View { trace {
            setupSelector(.init(groupId: group.id)) {
                content
            }
        } }
    }
}

// MARK: private

private extension ActiveItemView.GroupBounds {
    @ViewBuilder var content: some View {
        if let bounds = selector.bounds {
            AnimatableReader(selector.viewport) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.blue.opacity(selector.selected ? 0.1 : 0.03))
                    .stroke(.blue.opacity(selector.focused ? 0.8 : selector.selected ? 0.5 : 0.3), style: .init(lineWidth: 2))
                    .multipleTouchGesture(global.gesture(group: group))
                    .framePosition(rect: bounds.applying($0.worldToView).outset(by: selector.outset))
            }
        }
    }
}
