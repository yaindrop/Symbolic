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
    @Selected var toView = global.viewport.toView
    @Selected var viewSize = global.activeItem.store.activeItemIds
    @Selected var activePaths = activePathsSelector
    @Selected var activeGroups = activeGroupsSelector

    var body: some View {
        ForEach(activeGroups) {
            GroupBounds(activeGroup: $0, toView: toView)
        }
        ForEach(activePaths) {
            PathBounds(activePath: $0, toView: toView)
        }
    }
}

extension ActiveView {
    struct PathBounds: View {
        let activePath: Path
        let toView: CGAffineTransform

        @Selected var focused: Bool

        init(activePath: Path, toView: CGAffineTransform) {
            self.activePath = activePath
            self.toView = toView
            _focused = .init { global.activeItem.store.focusedItemId == activePath.id }
        }

        var body: some View {
            let rect = activePath.boundingRect.applying(toView)
            RoundedRectangle(cornerRadius: 2)
                .fill(focused ? .orange.opacity(0.5) : .blue.opacity(0.2))
                .stroke(focused ? .orange : .blue.opacity(0.5))
                .frame(width: rect.width, height: rect.height)
                .position(rect.center)
        }
    }

    struct GroupBounds: View {
        let activeGroup: ItemGroup
        let toView: CGAffineTransform

        @Selected var groupedPaths: [Path]
        @Selected var focused: Bool

        init(activeGroup: ItemGroup, toView: CGAffineTransform) {
            self.activeGroup = activeGroup
            self.toView = toView
            _groupedPaths = .init { activeGroup.members.compactMap { global.path.path(id: $0) } }
            _focused = .init { global.activeItem.store.focusedItemId == activeGroup.id }
        }

        var bounds: CGRect? {
            guard let first = groupedPaths.first else { return nil }
            var bounds = groupedPaths.dropFirst().reduce(into: first.boundingRect) { rect, path in rect = rect.union(path.boundingRect) }
            bounds = bounds.applying(toView)
            bounds = bounds.insetBy(dx: -4, dy: -4)
            return bounds
        }

        var body: some View {
            if let bounds {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(focused ? .orange : .blue.opacity(0.5), style: .init(lineWidth: 2))
                    .frame(width: bounds.width, height: bounds.height)
                    .position(bounds.center)
            }
        }
    }
}
