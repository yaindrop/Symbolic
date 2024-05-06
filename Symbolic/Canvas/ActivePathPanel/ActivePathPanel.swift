import Foundation
import SwiftUI

// MARK: - ActivePathPanel

struct ActivePathPanel: View {
    var body: some View {
        VStack {
            Spacer()
            VStack(spacing: 0) {
                title
                scrollView
            }
            .background(.regularMaterial)
            .cornerRadius(12)
        }
        .frame(maxWidth: 320, maxHeight: 480)
        .padding(24)
        .atCornerPosition(.bottomRight)
    }

    // MARK: private

    @EnvironmentObject private var pathStore: PathStore
    @EnvironmentObject private var activePathModel: ActivePathModel

    @StateObject private var scrollOffset = ScrollOffsetModel()

    @ViewBuilder private var title: some View {
        HStack {
            Spacer()
            Text("Active Path")
                .font(.headline)
                .fontWeight(.semibold)
                .padding(.vertical, 8)
            Spacer()
        }
        .padding(12)
        .if(scrollOffset.scrolled) { $0.background(.regularMaterial) }
    }

    @ViewBuilder private var scrollView: some View {
        if let activePath = activePathModel.pendingActivePath {
            ScrollViewReader { proxy in
                ScrollViewWithOffset(model: scrollOffset) {
                    Components(activePath: activePath).id(activePath.id)
                }
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
