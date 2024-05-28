import Foundation
import SwiftUI

private var selectedItemsSelector: [Item] {
    global.activeItem.selectedItemIds.compactMap { global.item.item(id: $0) }
}

private var boundsSelector: CGRect? {
    CGRect(union: selectedItemsSelector.compactMap { global.item.boundingRect(item: $0) })?.outset(by: 8)
}

struct SelectionView: View {
    @Selected var selectedItems = selectedItemsSelector
    @Selected var bounds = boundsSelector
    @Selected var toView = global.viewport.toView
    @Selected var viewSize = global.viewport.store.viewSize

    @State private var dashPhase: CGFloat = 0
    @State private var menuSize: CGSize = .zero

    var boundsInView: CGRect? { bounds?.applying(toView) }

    var body: some View {
//        ForEach(selectedPaths) {
//            PathBounds(selectedPath: $0, toView: toView, selectedPathIds: selectedPathIds)
//        }
        if let boundsInView {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.blue.opacity(0.5), style: .init(lineWidth: 2, dash: [8], dashPhase: dashPhase))
                .frame(width: boundsInView.width, height: boundsInView.height)
                .position(boundsInView.center)
                .modifier(AnimatedValue(value: $dashPhase, from: 0, to: 16, animation: .linear(duration: 0.4).repeatForever(autoreverses: false)))

            let menuAlign: PlaneOuterAlign = boundsInView.midY > CGRect(viewSize).midY ? .topCenter : .bottomCenter
            let menuBox = boundsInView.alignedBox(at: menuAlign, size: menuSize, gap: 8).clamped(by: CGRect(viewSize).insetBy(dx: 12, dy: 12))
            ContextMenu(onDelete: {
//                global.documentUpdater.update(path: .delete(.init(pathIds: selectedPathIds)))
            }, onGroup: {
                global.documentUpdater.update(item: .group(.init(group: .init(id: UUID(), members: selectedItems.map { $0.id }), inGroupId: nil)))
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
                        { v, _ in global.documentUpdater.updateInView(path: .move(.init(pathIds: selectedPathIds, offset: v.offset)), pending: pending) }
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
