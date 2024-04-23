import SwiftUI

struct DebugView: View {
    @ObservedObject var touchContext: MultipleTouchContext
    @ObservedObject var pressDetector: PressDetector

    @ObservedObject var viewport: Viewport
    @ObservedObject var viewportUpdater: ViewportUpdater

    @ObservedObject var pathModel: PathModel
    @ObservedObject var activePathModel: ActivePathModel

    var title: some View {
        HStack {
            Text("Debug")
                .font(.title3)
                .padding(.vertical, 4)
            Spacer()
        }
    }

    var body: some View {
        VStack {
            Group {
                VStack {
                    title
                    Row(name: "Pan", value: touchContext.panInfo?.description ?? "nil")
                    Row(name: "Pinch", value: touchContext.pinchInfo?.description ?? "nil")
                    Row(name: "Press", value: pressDetector.pressLocation?.shortDescription ?? "nil")
                    Divider()
                    Row(name: "Viewport", value: viewport.info.description)
                }
                .padding(12)
            }
            .background(.regularMaterial)
            .cornerRadius(12)
        }
        .frame(maxWidth: 360)
        .padding(24)
        .modifier(CornerPositionModifier(position: .topRight))
    }

    private struct Row: View {
        let name: String
        let value: String

        var body: some View {
            HStack {
                Text(name)
                    .font(.headline)
                Spacer()
                Text(value)
                    .font(.body)
                    .padding(.vertical, 4)
            }
        }
    }
}