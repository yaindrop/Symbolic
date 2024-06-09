import SwiftUI

// MARK: - global actions

private extension GlobalStore {
    func onTap(pathId: UUID) {
        if toolbar.multiSelect {
            activeItem.selectRemove(itemIds: [pathId])
        } else if activeItem.focusedItemId != pathId {
            activeItem.focus(itemId: pathId)
        } else if !focusedPath.selectingNodes {
            focusedPath.clear()
        }
    }
}

// MARK: - PathBounds

extension ActiveItemView {
    struct PathBounds: View, TracedView, ComputedSelectorHolder {
        struct SelectorProps: Equatable { let pathId: UUID }
        class Selector: SelectorBase {
            override var syncUpdate: Bool { true }
            @Selected({ global.activeItem.focusedItemId == $0.pathId }) var focused
            @Selected({ global.activeItem.selectedItemIds.contains($0.pathId) }) var selected
            @Selected({ global.activeItem.boundingRect(itemId: $0.pathId) }) var bounds
        }

        @SelectorWrapper var selector

        let path: Path

        var body: some View { trace {
            setupSelector(.init(pathId: path.id)) {
                boundsRect
            }
        } }

        // MARK: private

        @ViewBuilder private var boundsRect: some View {
            if let bounds = selector.bounds {
                RoundedRectangle(cornerRadius: 2)
                    .fill(.blue.opacity(selector.focused ? 0.2 : 0.1))
                    .stroke(.blue.opacity(selector.focused ? 0.8 : 0.5))
                    .multipleTouchGesture(.init(
                        onPress: {
                            global.canvasAction.start(continuous: .moveSelection)
                        },
                        onPressEnd: { cancelled in
                            global.canvasAction.end(continuous: .moveSelection)
                            if cancelled { global.documentUpdater.cancel() }
                        },
                        onTap: { _ in global.onTap(pathId: path.id) },
                        onDrag: { updateDrag($0, pending: true) },
                        onDragEnd: { updateDrag($0) }
                    ))
                    .framePosition(rect: bounds)
            }
        }

        private func updateDrag(_ v: PanInfo, pending: Bool = false) {
            if selector.selected {
                let selectedPathIds = global.activeItem.selectedPaths.map { $0.id }
                global.documentUpdater.updateInView(path: .move(.init(pathIds: selectedPathIds, offset: v.offset)), pending: pending)
            } else {
                global.documentUpdater.updateInView(path: .move(.init(pathIds: [path.id], offset: v.offset)), pending: pending)
            }
        }
    }
}
