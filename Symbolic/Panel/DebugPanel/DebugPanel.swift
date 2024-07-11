import SwiftUI

struct DebugPanel: View, SelectorHolder {
    @ObservedObject var multipleTouch: MultipleTouchModel
    var multipleTouchPress: MultipleTouchPressModel

    class Selector: SelectorBase {
        @Selected({ global.viewport.info }) var viewportInfo
    }

    @SelectorWrapper var selector

    var body: some View {
        setupSelector {
            content
        }
    }
}

private extension DebugPanel {
    var pressDetector: MultipleTouchPressDetector { .init(multipleTouch: multipleTouch, model: multipleTouchPress) }

    @ViewBuilder var content: some View {
        PanelBody(name: "Debug") { _ in
            touch
            viewport
        }
    }

    @ViewBuilder var touch: some View {
        PanelSection(name: "Multiple Touch") {
            Row(name: "Pan", value: multipleTouch.panInfo?.description ?? "nil")
            Divider()
                .padding(.leading, 12)
            Row(name: "Pinch", value: multipleTouch.pinchInfo?.description ?? "nil")
            Divider()
                .padding(.leading, 12)
            Row(name: "Press", value: pressDetector.pressLocation?.shortDescription ?? "nil")
        }
    }

    @ViewBuilder var viewport: some View {
        PanelSection(name: "Viewport") {
            Row(name: "Origin", value: selector.viewportInfo.origin.shortDescription)
            Divider()
                .padding(.leading, 12)
            Row(name: "Scale", value: selector.viewportInfo.scale.shortDescription)
        }
    }
}

private struct Row: View {
    let name: String
    let value: String

    var body: some View {
        HStack {
            Text(name)
                .font(.callout)
            Spacer()
            Text(value)
                .font(.callout)
                .padding(.vertical, 4)
        }
        .padding(12)
    }
}
