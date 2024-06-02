import SwiftUI

struct DebugPanel: View {
    let panelId: UUID

    var multipleTouch: MultipleTouchModel
    var multipleTouchPress: MultipleTouchPressModel

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

    @ViewBuilder private var panel: some View {
        VStack {
            title
                .invisibleSoildOverlay()
                .multipleGesture(global.panel.moveGesture(panelId: panelId))
            Row(name: "Pan", value: multipleTouch.panInfo?.description ?? "nil")
            Row(name: "Pinch", value: multipleTouch.pinchInfo?.description ?? "nil")
            Row(name: "Press", value: pressDetector.pressLocation?.shortDescription ?? "nil")
            Divider()
            Row(name: "Viewport", value: viewportInfo.description)
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipRounded(radius: 12)
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
