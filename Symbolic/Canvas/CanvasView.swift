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

class FooStore: Store {
    @Trackable var bar0: Int = 1
    @Trackable var bar1: Int = 1

    func update() {
        update {
            $0(\._bar0, bar0 + 1)
            $0(\._bar1, bar1 + 1)
        }
    }
}

let fooStore = FooStore()

struct FooView: View {
    @Selected var selected = fooStore.bar0 + fooStore.bar1

    var body: some View {
        Color.clear
            .onChange(of: selected) {
                print("FooView", selected)
            }
            .onAppear {
                tick()
            }
    }

    func tick() {
        fooStore.update()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: { tick() })
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
            .onChange(of: activeDocument) {
                withAnimation {
                    let _r = tracer.range("Reload document"); defer { _r() }
                    store.pendingPath.update(pendingEvent: nil)
                    service.path.loadDocument(activeDocument)
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
                    let worldLocation = info.location.applying(toWorld)
                    let _r = tracer.range("On tap \(worldLocation)", type: .intent); defer { _r() }
                    withAnimation {
                        store.activePath.update(activePathId: store.path.hitTest(worldPosition: worldLocation)?.id)
                    }
                }
                multipleTouchPress.onLongPress { info in
                    let worldLocation = info.current.applying(toWorld)
                    let _r = tracer.range("On long press \(worldLocation)", type: .intent); defer { _r() }
                    store.viewportUpdate.setBlocked(true)
                    if !pendingSelectionModel.active {
                        canvasActionModel.onStart(triggering: .longPressViewport)
                        longPressPosition = info.current
                        selectionUpdater.onStart(from: info.current)
                    }
                }
                multipleTouchPress.onLongPressEnd { _ in
                    let _r = tracer.range("On long press end", type: .intent); defer { _r() }
                    store.viewportUpdate.setBlocked(false)
                    //                    longPressPosition = nil
                    canvasActionModel.onEnd(triggering: .longPressViewport)
                    selectionUpdater.onEnd()
                }
            }
            .onAppear {
                store.pathUpdate.onPendingEvent {
                    store.pendingPath.update(pendingEvent: $0)
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
                store.document.setDocument(.init(from: fooSvg))
            }
    }}

    // MARK: private

    @Selected private var toView = store.viewport.toView
    @Selected private var toWorld = store.viewport.toWorld
    @Selected private var activeDocument = store.document.activeDocument
    @Selected private var paths = store.path.paths
    @Selected private var pendingActivePath = service.activePath.pendingActivePath

    private var pressDetector: MultipleTouchPressDetector { .init(multipleTouch: multipleTouch, model: multipleTouchPress) }
    private var selectionUpdater: SelectionUpdater { .init(pendingSelectionModel: pendingSelectionModel) }

    @State private var longPressPosition: Point2?

    // MARK: view builders

    @ViewBuilder private var navigationView: some View {
        NavigationSplitView(preferredCompactColumn: .constant(.detail)) {
//            FooView()
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
                context.concatenate(toView)
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
        ForEach(paths.filter { $0.id != pendingActivePath?.id }) { p in
            SUPath { path in p.append(to: &path) }
                .stroke(Color(UIColor.label), style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
        }
    } }

    @ViewBuilder var activePath: some View { tracer.range("CanvasView activePath") { build {
        if let pendingActivePath {
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
                .transformEffect(toView)
                .blur(radius: 1)
            foreground
            overlay
        }
    }}

    @ViewBuilder private var overlay: some View { tracer.range("CanvasView overlay") {
        ZStack {
            activePath
                .transformEffect(toView)
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
                var events = activeDocument.events
                guard let last = events.last else { return }
                if case let .pathAction(p) = last.action {
                    if case let .load(l) = p {
                        return
                    }
                }
                events.removeLast()
                store.document.setDocument(.init(events: events))
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
        }
    }}}
}

#Preview {
    CanvasView()
}
