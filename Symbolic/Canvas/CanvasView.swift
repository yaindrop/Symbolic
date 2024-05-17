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

struct CanvasView: View {
    // MARK: models

    @State var multipleTouch = MultipleTouchModel()
    @State var multipleTouchPress = MultipleTouchPressModel(configs: .init(durationThreshold: 0.2))

    @StateObject var pendingSelectionModel = PendingSelectionModel()

    @StateObject var panelModel = PanelModel()

    @State var canvasActionModel = CanvasActionModel()

    // MARK: body

    var body: some View { tracer.range("CanvasView body") {
        navigationView
            .onChange(of: store.document.activeDocument) {
                withAnimation {
                    let _r = tracer.range("Reload document"); defer { _r() }
                    store.pendingPath.pendingEvent = nil
                    service.path.loadDocument(store.document.activeDocument)
                }
            }
            .onChange(of: service.activePath.activePath) {
                let _r = tracer.range("Active path change \(service.activePath.activePath?.id.uuidString ?? "nil")"); defer { _r() }
                service.activePath.onActivePathChanged()
            }
            .onAppear {
                service.viewportUpdater.subscribe(to: multipleTouch)
                pressDetector.subscribe()
                service.path.subscribe()
                selectionUpdater.subscribe(to: multipleTouch)
            }
            .onAppear {
                multipleTouchPress.onTap { info in
                    let worldLocation = info.location.applying(store.viewport.toWorld)
                    let _r = tracer.range("On tap \(worldLocation)", type: .intent); defer { _r() }
                    withAnimation {
                        store.activePath.activePathId = store.path.hitTest(worldPosition: worldLocation)?.id
                    }
                }
                multipleTouchPress.onLongPress { info in
                    let worldLocation = info.current.applying(store.viewport.toWorld)
                    let _r = tracer.range("On long press \(worldLocation)", type: .intent); defer { _r() }
                    store.viewportUpdate.blocked = true
                    if !pendingSelectionModel.active {
                        canvasActionModel.onStart(triggering: .longPressViewport)
                        longPressPosition = info.current
                        selectionUpdater.onStart(from: info.current)
                    }
                }
                multipleTouchPress.onLongPressEnd { _ in
                    let _r = tracer.range("On long press end", type: .intent); defer { _r() }
                    store.viewportUpdate.blocked = false
                    //                    longPressPosition = nil
                    canvasActionModel.onEnd(triggering: .longPressViewport)
                    selectionUpdater.onEnd()
                }
            }
            .onAppear {
                store.pathUpdate.onPendingEvent { e in
                    store.pendingPath.pendingEvent = e
                }
                store.pathUpdate.onEvent { e in
                    withAnimation {
                        store.document.sendEvent(e)
                    }
                }
            }
            .onAppear {
                panelModel.register(align: .bottomTrailing) { ActivePathPanel() }
                panelModel.register(align: .bottomLeading) { HistoryPanel() }
                panelModel.register(align: .topTrailing) { DebugPanel(multipleTouch: multipleTouch, multipleTouchPress: multipleTouchPress) }
                panelModel.register(align: .topLeading) {
                    Text("hello?")
                        .padding()
                }
            }
            .onAppear {
                store.document.activeDocument = Document(from: fooSvg)
            }
    }}

    // MARK: private

    private var pressDetector: MultipleTouchPressDetector { .init(multipleTouch: multipleTouch, model: multipleTouchPress) }
    private var selectionUpdater: SelectionUpdater { .init(pendingSelectionModel: pendingSelectionModel) }

    @State private var longPressPosition: Point2?

    // MARK: view builders

    @ViewBuilder private var navigationView: some View {
        NavigationSplitView(preferredCompactColumn: .constant(.detail)) {
            Text("sidebar")
                .navigationTitle("Sidebar")
        } detail: {
            canvas
                .navigationBarTitleDisplayMode(.inline)
                .clipped()
                .edgesIgnoringSafeArea(.bottom)
                .toolbar { toolbar }
        }
    }

    @ViewBuilder private var background: some View { tracer.range("CanvasView background") {
        GeometryReader { geometry in
            Canvas { context, _ in
                context.concatenate(store.viewport.toView)
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
    } }

    @ViewBuilder var inactivePaths: some View { tracer.range("CanvasView inactivePaths") {
        ForEach(service.path.model.paths.filter { $0.id != service.activePath.activePathId }) { p in
            SUPath { path in p.append(to: &path) }
                .stroke(Color(UIColor.label), style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
        }
    } }

    @ViewBuilder var activePath: some View { tracer.range("CanvasView activePath") { build {
        if let pendingActivePath = service.activePath.pendingActivePath {
            SUPath { path in pendingActivePath.append(to: &path) }
                .stroke(Color(UIColor.label), style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
                .allowsHitTesting(false)
                .id(pendingActivePath.id)
        }
    } } }

    @ViewBuilder private var foreground: some View { tracer.range("CanvasView foreground") {
        Color.white.opacity(0.1)
            .modifier(MultipleTouchModifier(model: $multipleTouch))
    } }

    @ViewBuilder private var canvas: some View { tracer.range("CanvasView canvas") {
        ZStack {
            background
            inactivePaths
                .transformEffect(store.viewport.toView)
                .blur(radius: 1)
            foreground
            overlay
        }
    }}

    @ViewBuilder private var overlay: some View { tracer.range("CanvasView overlay") {
        ZStack {
            activePath
                .transformEffect(store.viewport.toView)
            ActivePathHandleRoot()
            PendingSelectionView()
                .environmentObject(pendingSelectionModel)
            PanelRoot()
                .environmentObject(panelModel)
            HoldActionPopover(position: longPressPosition)
        }
        .allowsHitTesting(!multipleTouch.active)
    } }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent { tracer.range("CanvasView toolbar") { build {
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
                var events = store.document.activeDocument.events
                guard let last = events.last else { return }
                if case let .pathAction(p) = last.action {
                    if case let .load(l) = p {
                        return
                    }
                }
                events.removeLast()
                store.document.activeDocument = Document(events: events)
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
        }
    }}}
}

#Preview {
    CanvasView()
}
