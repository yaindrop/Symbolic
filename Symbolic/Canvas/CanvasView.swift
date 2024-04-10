//
//  CanvasView.swift
//  Symbolic
//
//  Created by Yaindrop on 2024/4/8.
//

import Combine
import SwiftUI

struct CanvasView: View {
    @StateObject var context: MultipleTouchContext
    @StateObject var pressDetector: PressDetector
    @StateObject var viewportUpdater: Viewport

    init() {
        let context = MultipleTouchContext()
        _context = StateObject(wrappedValue: context)
        _pressDetector = StateObject(wrappedValue: PressDetector(context: context))
        _viewportUpdater = StateObject(wrappedValue: Viewport(context: context))
    }

    var body: some View {
        let rows: CGFloat = 10
        let cols: CGFloat = 10
        let gridColor: Color = .red

        Group {
            GeometryReader { geometry in
                Group {
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
                .transformEffect(viewportUpdater.info.worldToView)
                .onChange(of: geometry.size) { oldValue, newValue in
                    print("Changing size from \(oldValue) to \(newValue)")
                }
            }
            .modifier(MultipleTouchable(context: context))
            .onAppear {
                pressDetector.onTap { loc in print("onTap \(loc)") }
                pressDetector.onDoubleTap { loc in print("onDoubleTap \(loc)") }
            }
            VStack(alignment: HorizontalAlignment.leading) {
                Text("panInfo \(context.panInfo)")
                Text("pinchInfo \(context.pinchInfo)")
                Text("press \(pressDetector.isPress) \(pressDetector.pressLocation)")
                Text("viewport \(viewportUpdater.previousInfo) \(viewportUpdater.info)")
            }
        }
    }
}

#Preview {
    CanvasView()
}
