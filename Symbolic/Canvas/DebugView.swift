import SwiftUI

struct DebugTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.title3)
            .padding(.vertical, 4)
    }
}

struct DebugLine: View {
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

struct DebugDivider: View {
    var body: some View {
        Divider()
            .background(.white)
    }
}

struct DebugView: View {
    @ObservedObject var touchContext: MultipleTouchContext
    @ObservedObject var pressDetector: PressDetector

    @ObservedObject var viewport: Viewport
    @ObservedObject var viewportUpdater: ViewportUpdater

    @ObservedObject var pathModel: PathModel
    @ObservedObject var activePathModel: ActivePathModel

    @State private var columnVisibility = NavigationSplitViewVisibility.detailOnly

    var body: some View {
        HStack {
            Spacer()
            VStack {
                VStack(alignment: HorizontalAlignment.leading) {
                    DebugTitle(title: "Debug")
                    DebugLine(name: "Pan", value: touchContext.panInfo?.description ?? "nil")
                    DebugLine(name: "Pinch", value: touchContext.pinchInfo?.description ?? "nil")
                    DebugLine(name: "Press", value: pressDetector.pressLocation?.shortDescription ?? "nil")
                    DebugDivider()
                    DebugLine(name: "Viewport", value: viewport.info.description)
                    Button("Toggle sidebar", systemImage: "sidebar.left") {
                        print("columnVisibility", columnVisibility)
                        columnVisibility = columnVisibility == .detailOnly ? .doubleColumn : .detailOnly
                    }
                }
                .padding(12)
                .frame(maxWidth: 360)
                .background(.gray.opacity(0.5))
                .cornerRadius(12)
                Spacer()
            }
            .padding(24)
        }
    }
}
