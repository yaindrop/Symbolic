import Combine
import SwiftUI

struct BlurView: UIViewRepresentable {
    var style: UIBlurEffect.Style

    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: style))
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}

struct CanvasView: View {
    @StateObject var multipleTouch = MultipleTouchModel()
    @StateObject var multipleTouchPress = MultipleTouchPressModel(configs: .init(durationThreshold: 0.2))

    @StateObject var viewport = ViewportModel()
    @StateObject var viewportUpdate = ViewportUpdateModel()

    @StateObject var documentModel = DocumentModel()

    @StateObject var pathModel = PathModel()
    @StateObject var activePathModel = ActivePathModel()

    @StateObject var pathUpdateModel = PathUpdateModel()

    @StateObject var pendingSelectionModel = PendingSelectionModel()

    @StateObject var panelModel = PanelModel()

    @StateObject var canvasActionModel = CanvasActionModel()

    var pressDetector: MultipleTouchPressDetector { .init(multipleTouch, multipleTouchPress) }
    var viewportUpdater: ViewportUpdater { .init(viewport, viewportUpdate) }
    var activePathInteractor: ActivePathInteractor { .init(pathModel, activePathModel) }
    var updater: PathUpdater { .init(viewport, pathModel, activePathModel, pathUpdateModel) }
    var selectionUpdater: SelectionUpdater { .init(pendingSelectionModel) }

//    var stuff: some View {
//        RoundedRectangle(cornerRadius: 25)
//            .fill(.blue)
//            .frame(width: 200, height: 200)
//            .position(x: 300, y: 300)
//            .transformEffect(viewport.info.worldToView)
//        SUPath { path in
//            path.move(to: Point2(x: 400, y: 200))
//            path.addCurve(to: Point2(x: 400, y: 400), control1: Point2(x: 450, y: 250), control2: Point2(x: 350, y: 350))
//        }.stroke(lineWidth: 10)
//            .transformEffect(viewport.info.worldToView)
//    }

    var background: some View {
        GeometryReader { geometry in
            Canvas { context, _ in
                context.concatenate(viewport.toView)
                let path = SUPath { path in
                    for index in 0 ... 10240 {
                        let vOffset: Scalar = Scalar(index) * 10
                        path.move(to: Point2(vOffset, 0))
                        path.addLine(to: Point2(vOffset, 102400))
                    }
                    for index in 0 ... 10240 {
                        let hOffset: Scalar = Scalar(index) * 10
                        path.move(to: Point2(0, hOffset))
                        path.addLine(to: Point2(102400, hOffset))
                    }
                }
                context.stroke(path, with: .color(.red), lineWidth: 0.5)
            }
            //                Group {
            //                    Path { path in
            //                        for index in 0 ... 1024 {
            //                            let vOffset: Scalar = Scalar(index) * 10
            //                            path.move(to: Point2(x: vOffset, y: 0))
            //                            path.addLine(to: Point2(x: vOffset, y: 10240))
            //                        }
            //                        for index in 0 ... 1024 {
            //                            let hOffset: Scalar = Scalar(index) * 10
            //                            path.move(to: Point2(x: 0, y: hOffset))
            //                            path.addLine(to: Point2(x: 10240, y: hOffset))
            //                        }
            //                    }
            //                    .stroke(.red)
            //                }
            //                .transformEffect(viewport.info.worldToView)
            .onChange(of: geometry.size) { oldValue, newValue in
                print("Changing size from \(oldValue) to \(newValue)")
            }
        }
    }

    var inactivePaths: some View {
        activePathInteractor.inactivePathsView
            .transformEffect(viewport.toView)
            .blur(radius: 1)
    }

    @State var longPressPosition: Point2?

    var foreground: some View {
        Color.white.opacity(0.1)
            .modifier(MultipleTouchModifier(model: multipleTouch))
    }

    var activePaths: some View {
        activePathInteractor.activePathView
            .transformEffect(viewport.toView)
    }

    @ViewBuilder var overlay: some View {
        ZStack {
            activePaths
            ActivePathHandles()
            PendingSelectionView()
                .environmentObject(pendingSelectionModel)
            PanelRoot()
                .environmentObject(panelModel)
            HoldActionPopover(position: longPressPosition)
        }
        .allowsHitTesting(!multipleTouch.active)
    }

    var body: some View {
        NavigationSplitView(preferredCompactColumn: .constant(.detail)) {
            Text("sidebar")
                .navigationTitle("Sidebar")
        } detail: {
            ZStack {
                background
                inactivePaths
                foreground
                overlay
            }
//            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
//            .toolbar(.hidden, for: .navigationBar)
            .clipped()
            .edgesIgnoringSafeArea(.bottom)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Text("Item 0")
                        Divider()
                        Text("Item 1")
                    } label: {
                        HStack {
                            Text("未命名2").font(.headline)
                            Image(systemName: "chevron.down.circle.fill")
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(Color.label.opacity(0.5))
                                .font(.footnote)
                                .fontWeight(.black)
                        }
                        .tint(.label)
                    }
                }
                ToolbarItem(placement: .principal) {
                    HStack {
                        Button {} label: { Image(systemName: "rectangle.and.hand.point.up.left") }
                        Button {} label: { Image(systemName: "plus.circle") }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        var events = documentModel.activeDocument.events
                        guard let last = events.last else { return }
                        if case let .pathAction(p) = last.action {
                            if case let .load(l) = p {
                                return
                            }
                        }
                        events.removeLast()
                        documentModel.activeDocument = Document(events: events)
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                }
            }
        }
        .onChange(of: documentModel.activeDocument) {
            withAnimation {
                pathModel.pendingEvent = nil
                pathModel.clear()
                pathModel.loadDocument(documentModel.activeDocument)
            }
        }
        .onChange(of: activePathInteractor.activePath) {
            activePathInteractor.onActivePathChanged()
        }
        .onAppear {
            viewportUpdater.subscribe(to: multipleTouch)
            pressDetector.subscribe()
            selectionUpdater.subscribe(to: multipleTouch)

            multipleTouchPress.onTap { info in
                let worldLocation = info.location.applying(viewport.toWorld)
                print("onTap \(info) worldLocation \(worldLocation)")
                withAnimation {
                    activePathModel.activePathId = pathModel.hitTest(worldPosition: worldLocation)?.id
                }
            }
            multipleTouchPress.onLongPress { info in
                viewportUpdate.blocked = !info.isEnd
                if info.isEnd {
//                        longPressPosition = nil
                    canvasActionModel.onEnd(triggering: .longPressViewport)
                    selectionUpdater.onEnd()
                } else {
                    if !pendingSelectionModel.active {
                        canvasActionModel.onStart(triggering: .longPressViewport)
                        longPressPosition = info.location
                        selectionUpdater.onStart(from: info.location)
                    }
                }
                let worldLocation = info.location.applying(viewport.toWorld)
                print("onLongPress \(info) worldLocation \(worldLocation)")
            }

            pathUpdateModel.onPendingEvent { e in
                pathModel.pendingEvent = e
            }
            pathUpdateModel.onEvent { e in
                withAnimation {
                    documentModel.sendEvent(e)
                }
            }

            documentModel.activeDocument = Document(from: fooSvg)

            panelModel.register(align: .bottomTrailing) { ActivePathPanel() }
            panelModel.register(align: .bottomLeading) { HistoryPanel() }
            panelModel.register(align: .topTrailing) { DebugPanel().environmentObject(multipleTouch).environmentObject(multipleTouchPress) }
            panelModel.register(align: .topLeading) {
                Text("hello?")
                    .padding()
            }
        }
        .environmentObject(viewport)
        .environmentObject(documentModel)
        .environmentObject(pathModel)
        .environmentObject(activePathModel)
        .environmentObject(pathUpdateModel)
    }
}

#Preview {
    CanvasView()
}
