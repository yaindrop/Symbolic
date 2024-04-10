//
//  CanvasView.swift
//  Symbolic
//
//  Created by Yaindrop on 2024/4/8.
//

import Combine
import SwiftUI

struct CanvasView: View {
    @State var info = ViewportInfo()
    @State var gestureInfo = ViewportInfo()

    @GestureState private var translation = CGVector.zero

    var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .updating($translation) { value, state, _ in
                state = CGVector(dx: value.translation.width, dy: value.translation.height)
            }
            .onChanged { _ in
                print("translation", translation)
                gestureInfo.center = info.center + translation
            }
            .onEnded { _ in
                info.center = gestureInfo.center
            }
    }

    @GestureState var magnification = 1.0

    var magnifyGesture: some Gesture {
        MagnifyGesture()
            .updating($magnification) { value, state, _ in
                state = value.magnification
            }
            .onChanged { _ in
                print("magnification", magnification)
                gestureInfo.scale = info.scale * magnification
            }
            .onEnded { _ in
                info.scale = gestureInfo.scale
            }
    }

    @State private var tapLocation = CGPoint.zero

    var body: some View {
        let rows: CGFloat = 10
        let cols: CGFloat = 10
        let gridColor: Color = .red

        GeometryReader { proxy in
            Canvas { ctx, size in
                ctx.stroke(
                    Path(ellipseIn: CGRect(origin: .zero, size: size)),
                    with: .color(.green),
                    lineWidth: 4)
                let width = size.width
                let height = size.height
                let xSpacing = width / cols
                let ySpacing = height / rows
                let p = Path { path in
                    for index in 0 ... Int(cols) {
                        let vOffset: CGFloat = CGFloat(index) * xSpacing
                        path.move(to: CGPoint(x: vOffset, y: 0))
                        path.addLine(to: CGPoint(x: vOffset, y: height))
                    }
                    for index in 0 ... Int(rows) {
                        let hOffset: CGFloat = CGFloat(index) * ySpacing
                        path.move(to: CGPoint(x: 0, y: hOffset))
                        path.addLine(to: CGPoint(x: width, y: hOffset))
                    }
                }
                ctx.stroke(p, with: GraphicsContext.Shading.foreground, style: StrokeStyle())
            }
            .onChange(of: proxy.size) { oldValue, newValue in
                print("Changing size from \(oldValue) to \(newValue)")
            }
            .modifier(MultipleTouchable())
        }

        GeometryReader { geometry in

            let width = geometry.size.width
            let height = geometry.size.height
            let xSpacing = width / cols
            let ySpacing = height / rows

            Path { path in

                for index in 0 ... Int(cols) {
                    let vOffset: CGFloat = CGFloat(index) * xSpacing
                    path.move(to: CGPoint(x: vOffset, y: 0))
                    path.addLine(to: CGPoint(x: vOffset, y: height))
                }
                for index in 0 ... Int(rows) {
                    let hOffset: CGFloat = CGFloat(index) * ySpacing
                    path.move(to: CGPoint(x: 0, y: hOffset))
                    path.addLine(to: CGPoint(x: width, y: hOffset))
                }
            }
            .stroke(gridColor)
        }
    }
}

#Preview {
    CanvasView()
}
