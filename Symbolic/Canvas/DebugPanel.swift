import SwiftUI

struct DebugPanel: View {
    var body: some View {
        panel.frame(width: 320)
    }

    @ObservedObject var touchContext: MultipleTouchContext
    @ObservedObject var pressDetector: MultipleTouchPressDetector
    @ObservedObject var viewportUpdater: ViewportUpdater

    @EnvironmentObject var viewport: Viewport
    @EnvironmentObject var activePathModel: ActivePathModel

    @Environment(\.panelId) private var panelId
    @EnvironmentObject private var panelModel: PanelModel

    var title: some View {
        HStack {
            Text("Debug")
                .font(.title3)
                .padding(.vertical, 4)
            Spacer()
        }
    }

    @ViewBuilder private var panel: some View {
        VStack {
            title
                .invisibleSoildOverlay()
                .modifier(panelModel.moveGesture(panelId: panelId))
            Row(name: "Pan", value: touchContext.panInfo?.description ?? "nil")
            Row(name: "Pinch", value: touchContext.pinchInfo?.description ?? "nil")
            Row(name: "Press", value: pressDetector.location?.shortDescription ?? "nil")
            Divider()
            Row(name: "Viewport", value: viewport.info.description)
        }
        .padding(12)
        .background(.regularMaterial)
        .cornerRadius(12)
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
