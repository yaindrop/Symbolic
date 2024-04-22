import Foundation
import SwiftUI

struct ActivePathView: View {
    @ObservedObject var activePathModel: ActivePathModel

    var title: some View {
        HStack {
            Text("Active Path")
                .font(.title3)
                .padding(.vertical, 4)
            Spacer()
        }
    }

    var divider: some View {
        Divider()
            .background(.white)
    }

    var body: some View {
        VStack {
            Spacer()
            Group {
                VStack {
                    title
                    let pairs = activePathModel.activePath?.pairs ?? []
                    ScrollView {
                        VStack {
                            ForEach(Array(zip(pairs, pairs.indices)), id: \.0.0.id) { pair, index in
                                VertexRow(index: index, vertex: pair.0)
                                ActionRow(action: pair.1)
                            }
                        }
                    }
                    .frame(maxHeight: 400)
                    .fixedSize(horizontal: false, vertical: true)
                    .scrollBounceBehavior(.basedOnSize, axes: [.vertical])
                    .background(.blue.opacity(0.5))
                }
                .padding(12)
            }
            .background(.gray.opacity(0.5))
            .cornerRadius(12)
        }
        .frame(maxWidth: 360, maxHeight: 480)
        .background(.white.opacity(0.5))
        .padding(24)
        .modifier(CornerPositionModifier(position: .bottomRight))
    }

    private struct ActionRow: View {
        let action: PathAction

        var body: some View {
            HStack {
                Text("\(action)")
                    .font(.body)
                    .padding(.vertical, 4)
            }
        }
    }

    private struct VertexRow: View {
        let index: Int
        let vertex: PathVertex

        var body: some View {
            HStack {
                Text("\(index)")
                    .font(.headline)
                Spacer()
                Text("\(vertex.position)")
                    .font(.body)
                    .padding(.vertical, 4)
            }
        }
    }
}
