import SwiftUI

// MARK: - ActiveItemView

struct ActiveItemView: View, SelectorHolder {
    class Selector: SelectorBase {
        @Tracked({ global.viewport.info }) var viewport
        @Tracked({ global.activeItem.activePaths }) var activePaths
        @Tracked({ global.activeItem.activeGroups }) var activeGroups
    }

    @StateObject var selector = Selector()

    var body: some View { tracer.range("ActiveItemView body") { build {
        setupSelector {
            ForEach(selector.activeGroups) {
                GroupBounds(group: $0, viewport: selector.viewport)
            }
            ForEach(selector.activePaths) {
                PathBounds(path: $0, viewport: selector.viewport)
            }
            SelectionBounds()
        }
    } } }
}

// MARK: - GroupBounds

extension ActiveItemView {
    struct GroupBounds: View, ComputedSelectorHolder {
        typealias SelectorProps = UUID
        class Selector: SelectorBase {
            @Tracked({ groupId in global.activeItem.focusedItemId == groupId }) var focused
            @Tracked({ groupId in global.activeItem.selectedItemIds.contains(groupId) }) var selected
            @Tracked({ groupId in global.activeItem.boundingRect(itemId: groupId) }) var bounds
        }

        @StateObject var selector = Selector()

        let group: ItemGroup
        let viewport: ViewportInfo

        var body: some View {
            setupSelector(group.id) {
                boundsRect
            }
        }

        // MARK: private

        private var toView: CGAffineTransform { viewport.worldToView }

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
        typealias SelectorProps = UUID
        class Selector: SelectorBase {
            @Tracked({ pathId in global.activeItem.focusedItemId == pathId }) var focused
            @Tracked({ pathId in global.activeItem.selectedItemIds.contains(pathId) }) var selected
        }

        @StateObject var selector = Selector()

        let path: Path
        let viewport: ViewportInfo

        var body: some View { tracer.range("PathBounds body") {
            setupSelector(path.id) {
                boundsRect
            }
        } }

        // MARK: private

        private var toView: CGAffineTransform { viewport.worldToView }

        private var bounds: CGRect {
            path.boundingRect.applying(toView)
        }

        @ViewBuilder private var boundsRect: some View {
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

        private func updateDrag(_ v: PanInfo, pending: Bool = false) {
            if selector.selected {
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
    struct SelectionBounds: View, SelectorHolder {
        class Selector: SelectorBase {
            @Tracked({ global.activeItem.selectionBounds }) var bounds
        }

        @StateObject var selector = Selector()

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
