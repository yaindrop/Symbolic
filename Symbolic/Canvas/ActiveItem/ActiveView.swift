import SwiftUI

private var activePathsSelector: [Path] {
    global.activeItem.store.activeItemIds
        .compactMap { global.path.path(id: $0) }
}

private var activeGroupsSelector: [ItemGroup] {
    global.activeItem.store.activeItemIds
        .compactMap { global.item.group(id: $0) }
}

struct ActiveView: View {
    @Selected var viewport = global.viewport.info
    @Selected var viewSize = global.activeItem.store.activeItemIds
    @Selected var activePaths = activePathsSelector
    @Selected var activeGroups = activeGroupsSelector

    var body: some View {
        ForEach(activeGroups) {
            GroupBounds(group: $0, viewport: viewport)
        }
        ForEach(activePaths) {
            PathBounds(path: $0, viewport: viewport, groupedPaths: [])
        }
    }
}

extension ActiveView {
    struct GroupBounds: View {
        let group: ItemGroup
        let viewport: ViewportInfo

        var toWorld: CGAffineTransform { viewport.viewToWorld }
        var toView: CGAffineTransform { viewport.worldToView }

        @Selected var groupedPaths: [Path]
        @Selected var focused: Bool

        init(group: ItemGroup, viewport: ViewportInfo) {
            self.group = group
            self.viewport = viewport
            _groupedPaths = .init { global.item.leafItems(rootItemId: group.id).compactMap { $0.pathId }.compactMap { global.path.path(id: $0) } }
            _focused = .init { global.activeItem.store.focusedItemId == group.id }
        }

        var bounds: CGRect? {
            .init(union: groupedPaths.map { $0.boundingRect })?
                .applying(toView)
                .insetBy(dx: -4, dy: -4)
        }

        @State private var gesture = MultipleGestureModel<Void>()

        var body: some View {
            if let bounds {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.white.opacity(0.3))
                    .stroke(.blue.opacity(focused ? 0.8 : 0.3), style: .init(lineWidth: 2))
                    .frame(width: bounds.width, height: bounds.height)
                    .position(bounds.center)
                    .multipleGesture(gesture, ()) {
                        func update(pending: Bool = false) -> (DragGesture.Value, Void) -> Void {
                            { v, _ in global.documentUpdater.updateInView(path: .move(.init(pathIds: groupedPaths.map { $0.id }, offset: v.offset)), pending: pending) }
                        }
                        $0.onTap { v, _ in
                            let worldPosition = v.location.applying(toWorld)
                            let path = groupedPaths.first { $0.hitPath.contains(worldPosition) }
                            guard let path else { return }
                            global.activeItem.focus(itemId: path.id)
                        }
                        $0.onDrag(update(pending: true))
                        $0.onDragEnd(update())
                        $0.onTouchDown {
                            global.canvasAction.start(continuous: .moveSelection)
                        }
                        $0.onTouchUp {
                            global.canvasAction.end(continuous: .moveSelection)
                        }
                    }
            }
//            ForEach(groupedPaths) { path in
//                PathBounds(path: path, toView: toView, groupedPaths: groupedPaths)
//                let pathBounds = path.boundingRect.applying(toView)
//                Rectangle()
//                    .fill(.blue.opacity(0.2))
//                    .frame(width: pathBounds.width, height: pathBounds.height)
//                    .position(pathBounds.center)
//            }
        }
    }

    struct PathBounds: View {
        let path: Path
        let viewport: ViewportInfo
        let groupedPaths: [Path]

        var toView: CGAffineTransform { viewport.worldToView }

        @State private var gesture = MultipleGestureModel<Void>()

        init(path: Path, viewport: ViewportInfo, groupedPaths: [Path]) {
            self.path = path
            self.viewport = viewport
            self.groupedPaths = groupedPaths
        }

        var body: some View {
            let rect = path.boundingRect.applying(toView)
            RoundedRectangle(cornerRadius: 2)
                .fill(.blue.opacity(0.2))
                .stroke(.blue.opacity(0.5))
                .frame(width: rect.width, height: rect.height)
                .position(rect.center)
                .multipleGesture(gesture, ()) {
                    func update(pending: Bool = false) -> (DragGesture.Value, Void) -> Void {
                        { v, _ in global.documentUpdater.updateInView(path: .move(.init(pathIds: groupedPaths.map { $0.id }, offset: v.offset)), pending: pending) }
                    }
                    $0.onTap { _, _ in
                        global.activeItem.focus(itemId: path.id)
                    }
                    $0.onDrag(update(pending: true))
                    $0.onDragEnd(update())
                    $0.onTouchDown {
                        global.canvasAction.start(continuous: .moveSelection)
                    }
                    $0.onTouchUp {
                        global.canvasAction.end(continuous: .moveSelection)
                    }
                }
        }
    }
}
