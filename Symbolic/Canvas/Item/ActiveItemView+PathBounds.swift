import SwiftUI

// MARK: - global actions

private extension GlobalStores {
    func onTap(pathId: UUID) {
        if toolbar.multiSelect {
            activeItem.selectRemove(itemIds: [pathId])
        } else if activeItem.focusedItemId != pathId {
            activeItem.onTap(id: pathId)
        } else if !focusedPath.selectingNodes {
            focusedPath.selectionClear()
        }
    }

    func onDrag(pathId: UUID, _ v: PanInfo, pending: Bool = false) {
        let offset = v.offset.applying(activeSymbol.viewToSymbol),
            pathIds = activeItem.selected(id: pathId) ? activeItem.selectedPathIds : [pathId]
        documentUpdater.update(path: .move(.init(pathIds: pathIds, offset: offset)), pending: pending)
    }

    func gesture(pathId: UUID) -> MultipleTouchGesture {
        .init(
            onPress: { _ in
                canvasAction.start(continuous: .moveSelection)
            },
            onPressEnd: { cancelled in
                canvasAction.end(continuous: .moveSelection)
                if cancelled { documentUpdater.cancel() }
            },

            onTap: { _ in onTap(pathId: pathId) },
            onDrag: { onDrag(pathId: pathId, $0, pending: true) },
            onDragEnd: { onDrag(pathId: pathId, $0) },

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

// MARK: - PathBounds

extension ActiveItemView {
    struct PathBounds: View, TracedView, EquatableBy, ComputedSelectorHolder {
        @Environment(\.transformToView) var transformToView

        let pathId: UUID

        var equatableBy: some Equatable { pathId }

        struct SelectorProps: Equatable { let pathId: UUID }
        class Selector: SelectorBase {
            override var configs: SelectorConfigs { .syncNotify }
            @Selected({ global.item.boundingRect(of: $0.pathId) }) var bounds
            @Selected({ global.item.locked(of: $0.pathId) }) var locked
            @Selected({ global.activeItem.focusedItemId == $0.pathId }) var focused
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
            let bounds = bounds.applying(transformToView)
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.blue.opacity(fillOpacity))
                .stroke(.blue.opacity(strokeOpacity), style: .init(lineWidth: lineWidth))
                .multipleTouchGesture(global.gesture(pathId: pathId))
                .framePosition(rect: bounds)
                .opacity(selector.locked ? 0.5 : 1)
                .allowsHitTesting(!selector.locked)
        }
    }

    var cornerRadius: Scalar { 2 }

    var fillOpacity: Scalar { selector.focused ? 0.2 : 0.1 }

    var strokeOpacity: Scalar { selector.focused ? 0.8 : 0.5 }

    var lineWidth: Scalar { 1 }
}
