import Foundation
import SwiftUI

class SelectionStore: Store {
    @Trackable var selectedPathIds: Set<UUID> = []

    func update(pathIds: Set<UUID>) {
        update {
            $0(\._selectedPathIds, pathIds)
        }
    }
}

fileprivate var selectedPathsSelector: [Path] {
    let pathIds = global.selection.selectedPathIds
    return global.path.pendingPaths.filter { pathIds.contains($0.id) }
}

struct SelectionView: View {
    @Selected var selectedPaths = selectedPathsSelector
    @Selected var toView = global.viewport.toView

    @State private var dashPhase: CGFloat = 0

    var selectedPathIds: [UUID] { selectedPaths.map { $0.id }}

    var bounds: CGRect? {
        guard let first = selectedPaths.first else { return nil }
        var bounds = selectedPaths.dropFirst().reduce(into: first.boundingRect) { rect, path in rect = rect.union(path.boundingRect) }
        bounds = bounds.applying(toView)
        bounds = bounds.insetBy(dx: -4, dy: -4)
        return bounds
    }

    var body: some View {
        ForEach(selectedPaths) {
            PathBounds(selectedPath: $0, toView: toView, selectedPathIds: selectedPathIds)
        }
        if let bounds {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.blue.opacity(0.5), style: .init(lineWidth: 2, dash: [8], dashPhase: dashPhase))
                .frame(width: bounds.width, height: bounds.height)
                .position(bounds.center)
                .modifier(AnimatedValue(value: $dashPhase, from: 0, to: 16, animation: .linear(duration: 0.4).repeatForever(autoreverses: false)))
            ContextMenu(onDelete: {
                global.pathUpdater.delete(pathIds: selectedPathIds)
            })
            .position(bounds.center)
        }
    }
}

extension SelectionView {
    struct PathBounds: View {
        let selectedPath: Path
        let toView: CGAffineTransform
        let selectedPathIds: [UUID]

        @State private var gesture = MultipleGestureModel<Void>()

        var body: some View {
            let rect = selectedPath.boundingRect.applying(toView)
            RoundedRectangle(cornerRadius: 2)
                .fill(.blue.opacity(0.2))
                .stroke(.blue.opacity(0.5))
                .frame(width: rect.width, height: rect.height)
                .position(rect.center)
                .multipleGesture(gesture, ()) {
                    func update(pending: Bool = false) -> (DragGesture.Value, Void) -> Void {
                        { v, _ in global.pathUpdaterInView.update(pathIds: selectedPathIds, moveByOffset: Vector2(v.translation), pending: pending) }
                    }
                    $0.onDrag(update(pending: true))
                    $0.onDragEnd(update())
                    $0.onTouchDown {
                        global.canvasAction.start(continuous: .moveSelection)
                    }
                    $0.onTouchDown {
                        global.canvasAction.end(continuous: .moveSelection)
                    }
                }
        }
    }
}
