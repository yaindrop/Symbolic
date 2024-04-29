import Foundation
import SwiftUI

// MARK: - ActivePathPanel

struct ActivePathPanel: View {
    var body: some View {
        VStack {
            Spacer()
            Group {
                VStack(spacing: 0) {
                    title
                    ActivePathPanelComponents()
                }
            }
            .background(.regularMaterial)
            .cornerRadius(12)
        }
        .frame(maxWidth: 360, maxHeight: 480)
        .padding(24)
        .atCornerPosition(.bottomRight)
    }

    // MARK: private

    @EnvironmentObject private var pathStore: PathStore
    @EnvironmentObject private var activePathModel: ActivePathModel

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

    @StateObject private var scrollOffset = ScrollOffsetModel()
}
