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
    @Selected var viewSize = global.viewport.store.viewSize

    @State private var dashPhase: CGFloat = 0
    @State private var menuSize: CGSize = .zero

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

            let menuAlign: PlaneOuterAlign = bounds.midY > CGRect(viewSize).midY ? .topCenter : .bottomCenter
            let menuBox = bounds.alignedBox(at: menuAlign, size: menuSize, gap: 8).clamped(by: CGRect(viewSize).insetBy(dx: 12, dy: 12))
            ContextMenu(onDelete: {
                global.pathUpdater.update(.delete(.init(pathIds: selectedPathIds)))
            })
            .viewSizeReader { menuSize = $0 }
            .position(menuBox.center)
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
                        { v, _ in global.pathUpdater.updateInView(.move(.init(pathIds: selectedPathIds, offset: v.offset)), pending: pending) }
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
