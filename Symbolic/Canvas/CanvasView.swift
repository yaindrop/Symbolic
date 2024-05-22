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

    @StateObject var panelModel = PanelModel()

    // MARK: body

    var body: some View { tracer.range("CanvasView body") {
        navigationView
            .onChange(of: activeDocument) {
                withAnimation {
                    let _r = tracer.range("Reload document"); defer { _r() }
                    global.path.onPendingEvent(nil)
                    global.path.loadDocument(activeDocument)
                }
            }
            .onChange(of: global.activePath.activePath) {
                let _r = tracer.range("Active path change \(global.activePath.activePath?.id.uuidString ?? "nil")"); defer { _r() }
                global.activePath.onActivePathChanged()
            }
            .onAppear {
                global.viewportUpdater.subscribe(to: multipleTouch)
                pressDetector.subscribe()
                global.pendingSelection.subscribe(to: multipleTouch)
                global.addingPath.subscribe(to: multipleTouch)

                global.path.subscribe()
            }
            .onAppear {
                multipleTouchPress.onPress {
                    if case .select = toolbarMode {
                        global.canvasAction.start(triggering: .select)
                    } else if case .addPath = toolbarMode {
                        global.canvasAction.start(triggering: .addPath)
                    }
                }
                multipleTouchPress.onPressEnd {
                    global.canvasAction.end(triggering: .select)
                    global.canvasAction.end(triggering: .addPath)
                }
                multipleTouchPress.onTap { info in
                    let worldLocation = info.location.applying(toWorld)
                    let _r = tracer.range("On tap \(worldLocation)", type: .intent); defer { _r() }
                    withAnimation {
                        if !global.selection.selectedPathIds.isEmpty {
                            global.selection.update(pathIds: [])
                            global.canvasAction.on(instant: .cancelSelection)
                        }
                        if let pathId = global.path.hitTest(worldPosition: worldLocation)?.id {
                            global.canvasAction.on(instant: .activatePath)
                            global.activePath.activate(pathId: pathId)
                        } else if global.activePath.activePathId != nil {
                            global.canvasAction.on(instant: .deactivatePath)
                            global.activePath.deactivate()
                        }
                    }
                }
                multipleTouchPress.onLongPress { info in
                    let worldLocation = info.current.applying(toWorld)
                    let _r = tracer.range("On long press \(worldLocation)", type: .intent); defer { _r() }

                    global.viewportUpdater.setBlocked(true)
                    global.canvasAction.end(continuous: .panViewport)

                    global.canvasAction.end(triggering: .select)
                    global.canvasAction.end(triggering: .addPath)

                    if case .select = toolbarMode, !pendingSelectionActive {
                        longPressPosition = info.current
                        global.canvasAction.start(continuous: .pendingSelection)
                        global.pendingSelection.onStart(from: info.current)
                    } else if case let .addPath(addPath) = toolbarMode {
                        global.canvasAction.start(continuous: .addingPath)
                        global.addingPath.onStart(from: info.current)
                    }
                }
                multipleTouchPress.onLongPressEnd { _ in
                    let _r = tracer.range("On long press end", type: .intent); defer { _r() }
                    global.viewportUpdater.setBlocked(false)
                    //                    longPressPosition = nil

                    let selectedPaths = global.pendingSelection.intersectedPaths
                    if !selectedPaths.isEmpty {
                        global.selection.update(pathIds: Set(selectedPaths.map { $0.id }))
                        global.canvasAction.on(instant: .selectPaths)
                    }
                    global.pendingSelection.onEnd()
                    global.canvasAction.end(continuous: .pendingSelection)

                    if let path = global.addingPath.addingPath {
                        global.document.sendEvent(.init(kind: .pathEvent(.create(.init(path: path))), action: .pathAction(.create(.init(path: path)))))
                        global.activePath.activate(pathId: path.id)
                        global.canvasAction.on(instant: .addPath)
                    }
                    global.addingPath.onEnd()
                    global.canvasAction.end(continuous: .addingPath)
                }
            }
            .onAppear {
                global.pathUpdater.onPendingEvent {
                    global.path.onPendingEvent($0)
                }
                global.pathUpdater.onEvent { e in
                    withAnimation {
                        global.document.sendEvent(e)
                    }
                }
            }
            .onAppear {
                panelModel.register(align: .bottomTrailing) { ActivePathPanel() }
                panelModel.register(align: .bottomLeading) { HistoryPanel() }
                panelModel.register(align: .topTrailing) { DebugPanel(multipleTouch: multipleTouch, multipleTouchPress: multipleTouchPress) }
                panelModel.register(align: .topLeading) { CanvasActionPanel() }
            }
            .onAppear {
                global.document.setDocument(.init(from: fooSvg))
            }
    }}

    // MARK: private

    @Selected private var toView = global.viewport.toView
    @Selected private var toWorld = global.viewport.toWorld
    @Selected private var activeDocument = global.document.activeDocument
    @Selected private var pendingPaths = global.path.pendingPaths
    @Selected private var activePathId = global.activePath.activePathId
    @Selected private var pendingSelectionActive = global.pendingSelection.active
    @Selected private var toolbarMode = global.toolbar.mode

    private var pressDetector: MultipleTouchPressDetector { .init(multipleTouch: multipleTouch, model: multipleTouchPress) }

    private var isToolbarSelect: Bool { if case .select = toolbarMode { true } else { false } }
    private var isToolbarAddPath: Bool { if case .addPath = toolbarMode { true } else { false } }

    @State private var longPressPosition: Point2?

    // MARK: view builders

    @ViewBuilder private var navigationView: some View {
        NavigationSplitView(preferredCompactColumn: .constant(.detail)) {
//            FooView()
            Text("sidebar")
                .navigationTitle("Sidebar")
        } detail: {
            ZStack {
                canvas
                overlay
            }
            .navigationBarTitleDisplayMode(.inline)
            .clipped()
            .edgesIgnoringSafeArea(.bottom)
            .modifier(ToolbarModifier())
        }
    }

    @ViewBuilder private var background: some View { tracer.range("CanvasView background") {
        Background()
    } }

    @ViewBuilder var inactivePaths: some View { tracer.range("CanvasView inactivePaths") {
        ForEach(pendingPaths.filter { $0.id != activePathId }) { p in
            SUPath { path in p.append(to: &path) }
                .stroke(Color(UIColor.label), style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
        }
        .transformEffect(toView)
        .blur(radius: 1)
    } }

    @ViewBuilder private var foreground: some View { tracer.range("CanvasView foreground") {
        Color.white.opacity(0.1)
            .modifier(MultipleTouchModifier(model: $multipleTouch))
    } }

    @ViewBuilder private var canvas: some View { tracer.range("CanvasView canvas") {
        ZStack {
            background
            inactivePaths
            foreground
        }
        .viewSizeReader { global.viewport.setViewSize($0) }
    }}

    @ViewBuilder private var overlay: some View { tracer.range("CanvasView overlay") {
        ZStack {
            ActivePathView()
            PendingSelection()
            SelectionView()
            AddingPath()
            PanelRoot()
                .environmentObject(panelModel)
        }
        .allowsHitTesting(!multipleTouch.active)
    } }
}

#Preview {
    CanvasView()
}
