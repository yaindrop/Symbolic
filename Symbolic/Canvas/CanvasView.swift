//
//  CanvasView.swift
//  Symbolic
//
//  Created by Yaindrop on 2024/4/8.
//

import Combine
import SwiftUI

struct DebugTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.title3)
            .padding(.vertical, 4)
    }
}

struct DebugLine: View {
    let name: String
    let value: String

    var body: some View {
        HStack {
            Text(name)
                .font(.headline)
            Spacer()
            Text(value)
                .font(.body)
                .padding(.vertical, 4)
        }
    }
}

struct DebugDivider: View {
    var body: some View {
        Divider()
            .background(.white)
    }
}

struct CanvasView: View {
    @StateObject var touchContext: MultipleTouchContext
    @StateObject var pressDetector: PressDetector

    @StateObject var viewport: Viewport
    @StateObject var viewportUpdater: ViewportUpdater

    @StateObject var pathModel: PathModel

    init() {
        let viewport = Viewport()
        let touchContext = MultipleTouchContext()
        let pathModel = PathModel()
        foo(model: pathModel)
        _touchContext = StateObject(wrappedValue: touchContext)
        _pressDetector = StateObject(wrappedValue: PressDetector(touchContext: touchContext))
        _viewport = StateObject(wrappedValue: viewport)
        _viewportUpdater = StateObject(wrappedValue: ViewportUpdater(viewport: viewport, touchContext: touchContext))
        _pathModel = StateObject(wrappedValue: pathModel)
    }

    var debugView: some View {
        HStack {
            Spacer()
            VStack {
                VStack(alignment: HorizontalAlignment.leading) {
                    DebugTitle(title: "Debug")
                    DebugLine(name: "Pan", value: touchContext.panInfo?.description ?? "nil")
                    DebugLine(name: "Pinch", value: touchContext.pinchInfo?.description ?? "nil")
                    DebugLine(name: "Press", value: pressDetector.pressLocation?.shortDescription ?? "nil")
                    DebugDivider()
                    DebugLine(name: "Viewport", value: viewport.info.description)
                    Button("Toggle sidebar", systemImage: "sidebar.left") {
                        print("columnVisibility", columnVisibility)
                        columnVisibility = columnVisibility == .detailOnly ? .doubleColumn : .detailOnly
                    }
                }
                .padding(12)
                .frame(maxWidth: 360)
                .background(.gray.opacity(0.5))
                .cornerRadius(12)
                Spacer()
            }
            .padding(24)
        }
    }

    @State var active: Bool = false

    var stuff: some View {
//        RoundedRectangle(cornerRadius: 25)
//            .fill(.blue)
//            .frame(width: 200, height: 200)
//            .position(x: 300, y: 300)
//            .transformEffect(viewport.info.worldToView)
//        SwiftUI.Path { path in
//            path.move(to: CGPoint(x: 400, y: 200))
//            path.addCurve(to: CGPoint(x: 400, y: 400), control1: CGPoint(x: 450, y: 250), control2: CGPoint(x: 350, y: 350))
//        }.stroke(lineWidth: 10)
//            .transformEffect(viewport.info.worldToView)
        ForEach(pathModel.paths) { p in
            SwiftUI.Path { path in p.draw(path: &path) }
                .stroke(Color(UIColor.label), lineWidth: 1)
            p.vertexViews()
            p.controlViews()
        }
        .transformEffect(viewport.info.worldToView)
    }

    @State private var columnVisibility = NavigationSplitViewVisibility.detailOnly

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility, preferredCompactColumn: .constant(.detail)) {
            Text("sidebar")
                .navigationTitle("Sidebar")
        } detail: {
            ZStack {
                if !active {
                    stuff
                }
                GeometryReader { geometry in
                    Canvas { context, _ in
                        let path = SwiftUI.Path { path in
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
                .modifier(MultipleTouchModifier(context: touchContext))
                .onAppear {
                    pressDetector.onTap { info in
                        let worldLocation = info.location.applying(viewport.info.viewToWorld)
                        print("onTap \(info) worldLocation \(worldLocation)")
                        active = CGRect(center: CGPoint(x: 300, y: 300), size: CGSize(width: 200, height: 200)).contains(worldLocation)
                    }
                }
                if active {
                    stuff
                }
            }
            .overlay {
                debugView
            }
            .navigationTitle("Canvas")
//            .toolbar(.hidden, for: .navigationBar)
            .edgesIgnoringSafeArea(.all)
        }
    }
}

#Preview {
    CanvasView()
}
