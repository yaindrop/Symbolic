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

// MARK: - CanvasView

struct CanvasView: View, EnableViewportUpdater, EnablePathInteractor, EnableActivePathInteractor, EnablePathUpdater {
    // MARK: models

    @StateObject var multipleTouch = MultipleTouchModel()
    @StateObject var multipleTouchPress = MultipleTouchPressModel(configs: .init(durationThreshold: 0.2))

    @StateObject var viewport = ViewportModel()
    @StateObject var viewportUpdate = ViewportUpdateModel()

    @StateObject var documentModel = DocumentModel()

    @StateObject var pathModel = PathModel()
    @StateObject var pendingPathModel = PendingPathModel()
    @StateObject var activePathModel = ActivePathModel()

    @StateObject var pathUpdateModel = PathUpdateModel()

    @StateObject var pendingSelectionModel = PendingSelectionModel()

    @StateObject var panelModel = PanelModel()

    @StateObject var canvasActionModel = CanvasActionModel()

    // MARK: body

    var body: some View { tracer.range("CanvasView body") {
        navigationView
            .onChange(of: documentModel.activeDocument) {
                withAnimation {
                    let _r = tracer.range("Reload document"); defer { _r() }
                    pendingPathModel.pendingEvent = nil
                    pathInteractor.loadDocument(documentModel.activeDocument)
                }
            }
            .onChange(of: activePathInteractor.activePath) {
                let _r = tracer.range("Active path change \(activePathInteractor.activePath?.id.uuidString ?? "nil")"); defer { _r() }
                activePathInteractor.onActivePathChanged()
            }
            .onAppear {
                viewportUpdater.subscribe(to: multipleTouch)
                pressDetector.subscribe()
                pathInteractor.subscribe()
                selectionUpdater.subscribe(to: multipleTouch)
            }
            .onAppear {
                multipleTouchPress.onTap { info in
                    let worldLocation = info.location.applying(viewport.toWorld)
                    let _r = tracer.range("On tap \(worldLocation)"); defer { _r() }
                    withAnimation {
                        activePathModel.activePathId = pathModel.hitTest(worldPosition: worldLocation)?.id
                    }
                }
                multipleTouchPress.onLongPress { info in
                    let worldLocation = info.current.applying(viewport.toWorld)
                    let _r = tracer.range("On long press \(worldLocation)"); defer { _r() }
                    viewportUpdate.blocked = true
                    if !pendingSelectionModel.active {
                        canvasActionModel.onStart(triggering: .longPressViewport)
                        longPressPosition = info.current
                        selectionUpdater.onStart(from: info.current)
                    }
                }
                multipleTouchPress.onLongPressEnd { _ in
                    let _r = tracer.range("On long press end"); defer { _r() }
                    viewportUpdate.blocked = false
                    //                    longPressPosition = nil
                    canvasActionModel.onEnd(triggering: .longPressViewport)
                    selectionUpdater.onEnd()
                }
            }
            .onAppear {
                pathUpdateModel.onPendingEvent { e in
                    pendingPathModel.pendingEvent = e
                }
                pathUpdateModel.onEvent { e in
                    withAnimation {
                        documentModel.sendEvent(e)
                    }
                }
            }
            .onAppear {
                panelModel.register(align: .bottomTrailing) { ActivePathPanel() }
                panelModel.register(align: .bottomLeading) { HistoryPanel() }
                panelModel.register(align: .topTrailing) { DebugPanel().environmentObject(multipleTouch).environmentObject(multipleTouchPress) }
                panelModel.register(align: .topLeading) {
                    Text("hello?")
                        .padding()
                }
            }
            .onAppear {
                documentModel.activeDocument = Document(from: fooSvg)
            }
    }}

    // MARK: private

    // MARK: interactors

    private var pressDetector: MultipleTouchPressDetector { .init(multipleTouch: multipleTouch, model: multipleTouchPress) }
    private var selectionUpdater: SelectionUpdater { .init(pendingSelectionModel: pendingSelectionModel) }

    @State private var longPressPosition: Point2?

    // MARK: view builders

    @ViewBuilder private var navigationView: some View {
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
            .toolbar { toolbar }
        }
        .environmentObject(viewport)
        .environmentObject(documentModel)
        .environmentObject(pathModel)
        .environmentObject(pendingPathModel)
        .environmentObject(activePathModel)
        .environmentObject(pathUpdateModel)
    }

    @ViewBuilder private var background: some View {
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
                logInfo("Changing size from \(oldValue) to \(newValue)")
            }
        }
    }

    @ViewBuilder private var inactivePaths: some View {
        activePathInteractor.inactivePathsView
            .transformEffect(viewport.toView)
            .blur(radius: 1)
    }

    @ViewBuilder private var foreground: some View {
        Color.white.opacity(0.1)
            .modifier(MultipleTouchModifier(model: multipleTouch))
    }

    @ViewBuilder private var activePaths: some View {
        activePathInteractor.activePathView
            .transformEffect(viewport.toView)
    }

    @ViewBuilder private var overlay: some View {
        ZStack {
            activePaths
            ActivePathHandleRoot()
            PendingSelectionView()
                .environmentObject(pendingSelectionModel)
            PanelRoot()
                .environmentObject(panelModel)
            HoldActionPopover(position: longPressPosition)
        }
        .allowsHitTesting(!multipleTouch.active)
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
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

#Preview {
    CanvasView()
}
