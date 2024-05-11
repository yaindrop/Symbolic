import SwiftUI

struct DebugPanel: View {
    var body: some View {
        panel.frame(width: 320)
    }

    @EnvironmentObject var multipleTouch: MultipleTouchModel
    @EnvironmentObject var multipleTouchPress: MultipleTouchPressModel
    var pressDetector: MultipleTouchPressDetector { .init(multipleTouch: multipleTouch, model: multipleTouchPress)}

    @EnvironmentObject var viewport: ViewportModel
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
            Row(name: "Pan", value: multipleTouch.panInfo?.description ?? "nil")
            Row(name: "Pinch", value: multipleTouch.pinchInfo?.description ?? "nil")
            Row(name: "Press", value: pressDetector.pressLocation?.shortDescription ?? "nil")
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
