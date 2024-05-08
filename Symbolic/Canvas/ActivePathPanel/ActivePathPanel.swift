import Foundation
import SwiftUI

import SwiftUI

// MARK: - ActivePathPanel

struct ActivePathPanel: View {
    var body: some View {
        panel.frame(width: 320)
    }

    // MARK: private

    @EnvironmentObject private var pathStore: PathStore
    @EnvironmentObject private var activePathModel: ActivePathModel

    @StateObject private var scrollViewModel = ManagedScrollViewModel()

    @Environment(\.windowId) private var windowId
    @EnvironmentObject private var windowModel: WindowModel
    private var window: WindowData { windowModel.idToWindow[windowId]! }

    private var moveWindowGesture: MultipleGestureModifier<Point2> {
        MultipleGestureModifier(
            window.origin,
            configs: .init(coordinateSpace: .global),
            onDrag: { v, c in windowModel.onMoving(windowId: window.id, origin: c + v.offset) },
            onDragEnd: { v, c in windowModel.onMoved(windowId: window.id, origin: c + v.offset, inertia: v.inertia) }
        )
    }

    @ViewBuilder private var panel: some View {
        VStack(spacing: 0) {
            PanelTitle(name: "Active Path")
                .if(scrollViewModel.scrolled) { $0.background(.regularMaterial) }
                .invisibleSoildOverlay()
                .modifier(moveWindowGesture)
            scrollView
        }
        .background(.regularMaterial)
        .cornerRadius(12)
    }

    @ViewBuilder private var scrollView: some View {
        if let activePath = activePathModel.pendingActivePath {
            ManagedScrollView(model: scrollViewModel) { proxy in
                Components(activePath: activePath).id(activePath.id)
                    .onChange(of: activePathModel.focusedPart) {
                        guard let id = activePathModel.focusedPart?.id else { return }
                        withAnimation(.easeInOut(duration: 0.2)) { proxy.scrollTo(id, anchor: .center) }
                    }
            }
            .frame(maxHeight: 400)
            .fixedSize(horizontal: false, vertical: true)
            .scrollBounceBehavior(.basedOnSize, axes: [.vertical])
        }
    }
}
