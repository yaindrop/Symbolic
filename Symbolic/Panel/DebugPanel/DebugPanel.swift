import SwiftUI

struct DebugPanel: View {
    var multipleTouch: MultipleTouchModel
    var multipleTouchPress: MultipleTouchPressModel

    @Environment(\.panelId) private var panelId
    @EnvironmentObject private var panelModel: PanelModel

    var body: some View {
        panel.frame(width: 320)
    }

    var pressDetector: MultipleTouchPressDetector { .init(multipleTouch: multipleTouch, model: multipleTouchPress) }

    var title: some View {
        HStack {
            Text("Debug")
                .font(.title3)
                .padding(.vertical, 4)
            Spacer()
        }
    }

    @Selected private var viewportInfo = global.viewport.info
    @State private var moveContext = PanelMoveContext()

    @ViewBuilder private var panel: some View {
        VStack {
            title
                .invisibleSoildOverlay()
                .multipleGesture(panelModel.moveGesture(panel: panelModel.idToPanel[panelId], context: moveContext))
            Row(name: "Pan", value: multipleTouch.panInfo?.description ?? "nil")
            Row(name: "Pinch", value: multipleTouch.pinchInfo?.description ?? "nil")
            Row(name: "Press", value: pressDetector.pressLocation?.shortDescription ?? "nil")
            Divider()
            Row(name: "Viewport", value: viewportInfo.description)
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