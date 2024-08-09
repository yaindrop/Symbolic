import SwiftUI

// MARK: - global actions

private extension GlobalStores {
    func onTap(pathId: UUID) {
        if toolbar.multiSelect {
            activeItem.selectRemove(itemIds: [pathId])
        } else if activeItem.focusedItemId != pathId {
            activeItem.focus(itemId: pathId)
        } else if !focusedPath.selectingNodes {
            focusedPath.selectionClear()
        }
    }

    func onDrag(pathId: UUID, _ v: PanInfo, pending: Bool = false) {
        let offset = v.offset.applying(viewport.toWorld)
        if activeItem.selected(itemId: pathId) {
            let selectedPathIds = activeItem.selectedPaths.map { $0.id }
            documentUpdater.update(path: .move(.init(pathIds: selectedPathIds, offset: offset)), pending: pending)
        } else {
            documentUpdater.update(path: .move(.init(pathIds: [pathId], offset: offset)), pending: pending)
        }
    }

    func gesture(pathId: UUID) -> MultipleTouchGesture {
        .init(
            onPress: {
                canvasAction.start(continuous: .moveSelection)
            },
            onPressEnd: { cancelled in
                canvasAction.end(continuous: .moveSelection)
                if cancelled { documentUpdater.cancel() }
            },

            onTap: { _ in onTap(pathId: pathId) },
            onDrag: { onDrag(pathId: pathId, $0, pending: true) },
            onDragEnd: { onDrag(pathId: pathId, $0) },

            onPinch: { viewportUpdater.onPinch($0) },
            onPinchEnd: { _ in viewportUpdater.onCommit() }
        )
    }
}

// MARK: - PathBounds

extension ActiveItemView {
    struct PathBounds: View, TracedView, EquatableBy, ComputedSelectorHolder {
        let pathId: UUID

        var equatableBy: some Equatable { pathId }

        struct SelectorProps: Equatable { let pathId: UUID }
        class Selector: SelectorBase {
            override var configs: SelectorConfigs { .init(syncNotify: true) }
            @Selected({ global.viewport.sizedInfo }) var viewport
            @Selected({ global.item.boundingRect(itemId: $0.pathId) }) var bounds
            @Selected({ global.activeItem.focusedItemId == $0.pathId }) var focused
            @Selected({ global.activeItem.selectedItemIds.contains($0.pathId) }) var selected
        }

        @SelectorWrapper var selector

        var body: some View { trace {
            setupSelector(.init(pathId: pathId)) {
                content
            }
        } }
    }
}

// MARK: private

extension ActiveItemView.PathBounds {
    @ViewBuilder var content: some View {
        if let bounds = selector.bounds {
            AnimatableReader(selector.viewport) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(.blue.opacity(selector.focused ? 0.2 : 0.1))
                    .stroke(.blue.opacity(selector.focused ? 0.8 : 0.5))
                    .multipleTouchGesture(global.gesture(pathId: pathId))
                    .framePosition(rect: bounds.applying($0.worldToView))
            }
        }
    }

    func updateDrag(_ v: PanInfo, pending: Bool = false) {
        let offset = v.offset.applying(global.viewport.toWorld)
        if selector.selected {
            let selectedPathIds = global.activeItem.selectedPaths.map { $0.id }
            global.documentUpdater.update(path: .move(.init(pathIds: selectedPathIds, offset: offset)), pending: pending)
        } else {
            global.documentUpdater.update(path: .move(.init(pathIds: [pathId], offset: offset)), pending: pending)
        }
    }
}
