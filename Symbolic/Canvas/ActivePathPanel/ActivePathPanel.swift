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
                        .padding(12)
                        .if(scrollOffset.scrolled) { $0.background(.regularMaterial) }
                    ActivePathPanelComponents()
                }
            }
            .background(.regularMaterial)
            .cornerRadius(12)
        }
        .frame(maxWidth: 360, maxHeight: 480)
        .padding(24)
        .modifier(CornerPositionModifier(position: .bottomRight))
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
    }

    @ViewBuilder private func sectionTitle(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Color.secondaryLabel)
                .padding(.leading, 12)
            Spacer()
        }
    }

    @StateObject private var scrollOffset = ScrollOffsetModel()
}
