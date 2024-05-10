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
    @StateObject var touchContext: MultipleTouchContext
    @StateObject var pressDetector: MultipleTouchPressDetector

    @StateObject var viewport: Viewport
    @StateObject var viewportUpdater: ViewportUpdater

    @StateObject var documentModel: DocumentModel

    @StateObject var pathStore: PathStore
    @StateObject var activePathModel: ActivePathModel
    @StateObject var pathUpdater: PathUpdater

    @StateObject var pendingSelection: PendingSelection

    @StateObject var panelModel = PanelModel()

    init() {
        let touchContext = MultipleTouchContext()

        let viewport = Viewport()

        let documentModel = DocumentModel()

        let pathStore = PathStore()
        let activePathModel = ActivePathModel(pathStore: pathStore)
        let pathUpdater = PathUpdater(pathStore: pathStore, activePathModel: activePathModel, viewport: viewport)

        let pendingSelection = PendingSelection(touchContext: touchContext)

        pathUpdater.onPendingEvent { e in
            pathStore.pendingEvent = e
        }
        pathUpdater.onEvent { e in
            withAnimation {
                documentModel.sendEvent(e)
            }
        }

        _touchContext = StateObject(wrappedValue: touchContext)
        _pressDetector = StateObject(wrappedValue: .init(multipleTouch: touchContext, configs: .init(durationThreshold: 0.2)))
        _viewport = StateObject(wrappedValue: viewport)
        _viewportUpdater = StateObject(wrappedValue: .init(viewport: viewport, touchContext: touchContext))
        _documentModel = StateObject(wrappedValue: documentModel)
        _pathStore = StateObject(wrappedValue: pathStore)
        _activePathModel = StateObject(wrappedValue: activePathModel)
        _pathUpdater = StateObject(wrappedValue: pathUpdater)
        _pendingSelection = StateObject(wrappedValue: pendingSelection)
    }

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
        activePathModel.inactivePathsView
            .transformEffect(viewport.toView)
            .blur(radius: 1)
    }

    var foreground: some View {
        Color.white.opacity(0.1)
            .modifier(MultipleTouchModifier(context: touchContext))
            .onAppear {
                pressDetector.onTap { info in
                    let worldLocation = info.location.applying(viewport.toWorld)
                    print("onTap \(info) worldLocation \(worldLocation)")
                    withAnimation {
                        activePathModel.activePathId = pathStore.hitTest(worldPosition: worldLocation)?.id
                    }
                }
                pressDetector.onLongPress { info in
                    viewportUpdater.blocked = !info.isEnd
                    if info.isEnd {
                        pendingSelection.onEnd()
                    } else {
                        if !pendingSelection.active {
                            pendingSelection.onStart(from: info.location)
                        }
                    }
                    let worldLocation = info.location.applying(viewport.toWorld)
                    print("onLongPress \(info) worldLocation \(worldLocation)")
                }
            }
    }

    var activePaths: some View {
        activePathModel.activePathView
            .transformEffect(viewport.toView)
    }

    @ViewBuilder var overlay: some View {
        ZStack {
            activePaths
            ActivePathHandles()
            PendingSelectionView()
                .environmentObject(pendingSelection)
            PanelRoot()
                .environmentObject(panelModel)
        }
        .allowsHitTesting(!touchContext.active)
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
                    Text("Canvas").font(.headline)
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
                pathStore.pendingEvent = nil
                pathStore.clear()
                pathStore.loadDocument(documentModel.activeDocument)
            }
        }
        .onChange(of: activePathModel.activePath) {
            activePathModel.onActivePathChanged()
        }
        .onAppear {
            documentModel.activeDocument = Document(from: fooSvg)
            panelModel.register(align: .bottomTrailing) { ActivePathPanel() }
            panelModel.register(align: .bottomLeading) { HistoryPanel() }
            panelModel.register(align: .topTrailing) { DebugPanel(touchContext: touchContext, pressDetector: pressDetector, viewportUpdater: viewportUpdater) }
            panelModel.register(align: .topLeading) { Text("hello?").frame(width: 80, height: 40) }
        }
        .environmentObject(viewport)
        .environmentObject(documentModel)
        .environmentObject(pathStore)
        .environmentObject(activePathModel)
        .environmentObject(pathUpdater)
    }
}

#Preview {
    CanvasView()
}
