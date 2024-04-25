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
    @StateObject var pressDetector: PressDetector

    @StateObject var viewport: Viewport
    @StateObject var viewportUpdater: ViewportUpdater

    @StateObject var documentModel: DocumentModel = DocumentModel()
    @StateObject var pathStore: PathStore
    @StateObject var activePathModel: ActivePathModel

    init() {
        let viewport = Viewport()
        let touchContext = MultipleTouchContext()
        let pathStore = PathStore()
        let activePathModel = ActivePathModel(pathStore: pathStore)
        _touchContext = StateObject(wrappedValue: touchContext)
        _pressDetector = StateObject(wrappedValue: PressDetector(touchContext: touchContext))
        _viewport = StateObject(wrappedValue: viewport)
        _viewportUpdater = StateObject(wrappedValue: ViewportUpdater(viewport: viewport, touchContext: touchContext))
        _pathStore = StateObject(wrappedValue: pathStore)
        _activePathModel = StateObject(wrappedValue: activePathModel)
    }

//    var stuff: some View {
//        RoundedRectangle(cornerRadius: 25)
//            .fill(.blue)
//            .frame(width: 200, height: 200)
//            .position(x: 300, y: 300)
//            .transformEffect(viewport.info.worldToView)
//        SUPath { path in
//            path.move(to: CGPoint(x: 400, y: 200))
//            path.addCurve(to: CGPoint(x: 400, y: 400), control1: CGPoint(x: 450, y: 250), control2: CGPoint(x: 350, y: 350))
//        }.stroke(lineWidth: 10)
//            .transformEffect(viewport.info.worldToView)
//    }

    var background: some View {
        GeometryReader { geometry in
            Canvas { context, _ in
                context.concatenate(viewport.info.worldToView)
                let path = SUPath { path in
                    for index in 0 ... 10240 {
                        let vOffset: CGFloat = CGFloat(index) * 10
                        path.move(to: CGPoint(vOffset, 0))
                        path.addLine(to: CGPoint(vOffset, 102400))
                    }
                    for index in 0 ... 10240 {
                        let hOffset: CGFloat = CGFloat(index) * 10
                        path.move(to: CGPoint(0, hOffset))
                        path.addLine(to: CGPoint(102400, hOffset))
                    }
                }
                context.stroke(path, with: .color(.red), lineWidth: 0.5)
            }
            //                Group {
            //                    Path { path in
            //                        for index in 0 ... 1024 {
            //                            let vOffset: CGFloat = CGFloat(index) * 10
            //                            path.move(to: CGPoint(x: vOffset, y: 0))
            //                            path.addLine(to: CGPoint(x: vOffset, y: 10240))
            //                        }
            //                        for index in 0 ... 1024 {
            //                            let hOffset: CGFloat = CGFloat(index) * 10
            //                            path.move(to: CGPoint(x: 0, y: hOffset))
            //                            path.addLine(to: CGPoint(x: 10240, y: hOffset))
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
            .transformEffect(viewport.info.worldToView)
            .blur(radius: 1)
    }

    var foreground: some View {
        Canvas { context, size in
            let rect = Rectangle().path(in: CGRect(size))
            context.fill(rect, with: .color(.white.opacity(0.1)))
        }
        .modifier(MultipleTouchModifier(context: touchContext))
        .onAppear {
            pressDetector.onTap { info in
                let worldLocation = info.location.applying(viewport.info.viewToWorld)
                print("onTap \(info) worldLocation \(worldLocation)")
                activePathModel.activePathId = pathStore.hitTest(worldPosition: worldLocation)?.id
            }
        }
    }

    var activePaths: some View {
        activePathModel.activePathView
            .transformEffect(viewport.info.worldToView)
    }

    @ViewBuilder var overlay: some View {
        ActivePathHandles()
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
                activePaths
                overlay
            }
            .overlay {
                ActivePathPanel(activePathModel: activePathModel)
                DebugView(touchContext: touchContext, pressDetector: pressDetector, viewport: viewport, viewportUpdater: viewportUpdater, activePathModel: activePathModel)
            }
            .navigationTitle("Canvas")
            .toolbar(.hidden, for: .navigationBar)
            .edgesIgnoringSafeArea(.all)
        }
        .onChange(of: documentModel.activeDocument) {
            pathStore.clear()
            pathStore.loadDocument(documentModel.activeDocument)
        }
        .onAppear {
            documentModel.activeDocument = Document(from: fooSvg)
        }
        .environmentObject(viewport)
        .environmentObject(documentModel)
        .environmentObject(pathStore)
        .environmentObject(activePathModel)
    }
}

#Preview {
    CanvasView()
}
