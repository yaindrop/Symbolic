import SwiftUI

// MARK: - global actions

private extension GlobalStores {
    func onTap(group: Item.Group, position: Point2) {
        let worldPosition = position.applying(viewport.viewToWorld)
        let groupedPathIds = item.groupedPathIds(groupId: group.id)
        let path = groupedPathIds.first {
            activeSymbol.pathHitTest(pathId: $0, worldPosition: worldPosition, threshold: 32)
        }
        if let path {
            if toolbar.multiSelect {
                activeItem.selectAdd(itemId: path.id)
            } else {
                activeItem.onTap(id: path.id)
            }
        } else {
            if toolbar.multiSelect {
                if activeItem.selected(id: group.id) {
                    activeItem.selectRemove(itemIds: [group.id])
                } else {
                    let activeDescendants = item.expandedItems(rootId: group.id)
                        .filter { $0.id != group.id && activeItem.activeItemIds.contains($0.id) }
                    activeItem.selectRemove(itemIds: activeDescendants.map { $0.id })
                }
            } else {
                activeItem.onTap(id: group.id)
            }
        }
    }

    func onDrag(group: Item.Group, _ v: PanInfo, pending: Bool = false) {
        let offset = v.offset.applying(activeSymbol.viewToSymbol),
            pathIds = activeItem.selected(id: group.id) ? activeItem.selectedPathIds : item.groupedPathIds(groupId: group.id)
        documentUpdater.update(path: .move(.init(pathIds: pathIds, offset: offset)), pending: pending)
    }

    func gesture(group: Item.Group) -> MultipleTouchGesture {
        .init(
            onPress: { _ in
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

            onPinch: {
                canvasAction.start(continuous: .pinchViewport)
                viewportUpdater.onPinch($0)
            },
            onPinchEnd: { _ in
                canvasAction.end(continuous: .pinchViewport)
                viewportUpdater.onCommit()
            }
        )
    }
}

// MARK: - GroupBounds

extension ActiveItemView {
    struct GroupBounds: View, TracedView, EquatableBy, ComputedSelectorHolder {
        @Environment(\.transformToView) var transformToView

        let group: Item.Group

        var equatableBy: some Equatable { group }

        struct SelectorProps: Equatable { let groupId: UUID }
        class Selector: SelectorBase {
            override var configs: SelectorConfigs { .syncNotify }
            @Selected({ global.item.boundingRect(of: $0.groupId) }) var bounds
            @Selected({ global.item.locked(of: $0.groupId) }) var locked
            @Selected({ global.activeItem.groupOutset(id: $0.groupId) }) var outset
            @Selected({ global.activeItem.focusedItemId == $0.groupId }) var focused
            @Selected({ global.activeItem.selectedItemIds.contains($0.groupId) }) var selected
            @Selected({ !global.activeItem.groupActiveDescendants(id: $0.groupId).isEmpty }) var hasActiveDescendants
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
            let bounds = bounds.applying(transformToView).outset(by: selector.outset)
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.blue.opacity(fillOpacity))
                .stroke(.blue.opacity(strokeOpacity), style: .init(lineWidth: lineWidth))
                .multipleTouchGesture(global.gesture(group: group))
                .framePosition(rect: bounds)
                .opacity(selector.locked ? 0.5 : 1)
                .allowsHitTesting(!selector.locked && !selector.hasActiveDescendants)
        }
    }

    var cornerRadius: Scalar { 8 }

    var fillOpacity: Scalar { selector.selected ? 0.1 : 0.03 }

    var strokeOpacity: Scalar { selector.focused ? 0.8 : selector.selected ? 0.5 : 0.3 }

    var lineWidth: Scalar { 2 }
}
