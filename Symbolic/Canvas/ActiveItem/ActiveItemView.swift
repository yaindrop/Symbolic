import SwiftUI

// MARK: - ActiveItemView

struct ActiveItemView: View, SelectorHolder {
    class Selector: SelectorBase {
        @Selected({ global.activeItem.activePaths }) var activePaths
        @Selected({ global.activeItem.activeGroups }) var activeGroups
    }

    @SelectorWrapper var selector

    var body: some View { tracer.range("ActiveItemView body") {
        setupSelector {
            ForEach(selector.activeGroups) {
                GroupBounds(group: $0)
            }
            ForEach(selector.activePaths) {
                PathBounds(path: $0)
            }
            SelectionBounds()
        }
    } }
}

// MARK: - GroupBounds

extension ActiveItemView {
    struct GroupBounds: View, ComputedSelectorHolder {
        struct SelectorProps: Equatable { let groupId: UUID }
        class Selector: SelectorBase {
            override var syncUpdate: Bool { true }

            @Selected({ global.activeItem.focusedItemId == $0.groupId }) var focused
            @Selected({ global.activeItem.selectedItemIds.contains($0.groupId) }) var selected
            @Selected({ global.activeItem.boundingRect(itemId: $0.groupId) }) var bounds
        }

        @SelectorWrapper var selector

        let group: ItemGroup

        var body: some View {
            setupSelector(.init(groupId: group.id)) {
                boundsRect
            }
        }

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

                        onTap: {
                            global.activeItem.onTap(group: group, position: $0.location)
                        },
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

// MARK: - PathBounds

extension ActiveItemView {
    struct PathBounds: View, ComputedSelectorHolder {
        struct SelectorProps: Equatable { let pathId: UUID }
        class Selector: SelectorBase {
            override var syncUpdate: Bool { true }

            @Selected({ global.activeItem.focusedItemId == $0.pathId }) var focused
            @Selected({ global.activeItem.selectedItemIds.contains($0.pathId) }) var selected
            @Selected({ global.activeItem.boundingRect(itemId: $0.pathId) }) var bounds
        }

        @SelectorWrapper var selector

        let path: Path

        var body: some View { tracer.range("PathBounds body") {
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
                        onTap: { _ in global.activeItem.onTap(pathId: path.id) },
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

// MARK: - SelectionBounds

extension ActiveItemView {
    struct SelectionBounds: View, SelectorHolder {
        class Selector: SelectorBase {
            override var syncUpdate: Bool { true }

            @Selected({ global.activeItem.selectionBounds }) var bounds
        }

        @SelectorWrapper var selector

        var body: some View {
            setupSelector {
                boundsRect
            }
        }

        // MARK: private

        @State private var dashPhase: Scalar = 0

        @ViewBuilder private var boundsRect: some View {
            if let bounds = selector.bounds {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.blue.opacity(0.5), style: .init(lineWidth: 2, dash: [8], dashPhase: dashPhase))
                    .framePosition(rect: bounds)
                    .modifier(AnimatedValue(value: $dashPhase, from: 0, to: 16, animation: .linear(duration: 0.4).repeatForever(autoreverses: false)))
            }
        }
    }
}
