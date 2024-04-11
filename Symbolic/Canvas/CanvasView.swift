//
//  CanvasView.swift
//  Symbolic
//
//  Created by Yaindrop on 2024/4/8.
//

import Combine
import SwiftUI

struct CanvasView: View {
    @StateObject var touchContext: MultipleTouchContext
    @StateObject var pressDetector: PressDetector

    @StateObject var viewport: Viewport
    @StateObject var viewportUpdater: ViewportUpdater

    init() {
        let viewport = Viewport()
        let touchContext = MultipleTouchContext()
        _touchContext = StateObject(wrappedValue: touchContext)
        _pressDetector = StateObject(wrappedValue: PressDetector(touchContext: touchContext))
        _viewport = StateObject(wrappedValue: viewport)
        _viewportUpdater = StateObject(wrappedValue: ViewportUpdater(viewport: viewport, touchContext: touchContext))
        BezierPath.foo()
    }

    @State var active: Bool = false

    var stuff: some View {
//        RoundedRectangle(cornerRadius: 25)
//            .fill(.blue)
//            .frame(width: 200, height: 200)
//            .position(x: 300, y: 300)
//            .transformEffect(viewport.info.worldToView)
        Path { path in
            path.move(to: CGPoint(x: 400, y: 200))
            path.addCurve(to: CGPoint(x: 400, y: 400), control1: CGPoint(x: 450, y: 250), control2: CGPoint(x: 350, y: 350))
        }.stroke(lineWidth: 10)
            .transformEffect(viewport.info.worldToView)
    }

    var body: some View {
        ZStack {
            if !active {
                stuff
            }
            GeometryReader { geometry in
                Canvas { context, _ in
                    let path = Path { path in
                        for index in 0 ... 10240 {
                            let vOffset: CGFloat = CGFloat(index) * 10
                            path.move(to: CGPoint(x: vOffset, y: 0))
                            path.addLine(to: CGPoint(x: vOffset, y: 102400))
                        }
                        for index in 0 ... 10240 {
                            let hOffset: CGFloat = CGFloat(index) * 10
                            path.move(to: CGPoint(x: 0, y: hOffset))
                            path.addLine(to: CGPoint(x: 102400, y: hOffset))
                        }
                    }
                    context.concatenate(viewport.info.worldToView)
                    context.stroke(path, with: .color(.red))
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
            .modifier(MultipleTouchModifier(context: touchContext))
            .onAppear {
                pressDetector.onTap { info in
                    print("onTap \(info)")
                    let worldLocation = info.location.applying(viewport.info.viewToWorld)
                    print("worldLocation \(worldLocation)")
                    active = CGRect(center: CGPoint(x: 300, y: 300), size: CGSize(width: 200, height: 200)).contains(worldLocation)
                }
            }
            if active {
                stuff
            }
            VStack(alignment: HorizontalAlignment.leading) {
                Text("panInfo \(touchContext.panInfo?.description ?? "nil")")
                Text("pinchInfo \(touchContext.pinchInfo?.description ?? "nil")")
                Text("pressLocation \(pressDetector.pressLocation?.shortDescription ?? "nil")")
                Text("viewport \(viewportUpdater.previousInfo) \(viewport.info)")
            }
        }
    }
}

#Preview {
    CanvasView()
}
