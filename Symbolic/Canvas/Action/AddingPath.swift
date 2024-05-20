import Combine
import Foundation
import SwiftUI

class AddingPathStore: Store {
    @Trackable var from: Point2? = nil
    @Trackable var to: Point2 = .zero

    var active: Bool { from != nil }

    func onStart(from: Point2) {
        update {
            $0(\._from, from)
            $0(\._to, from)
        }
    }

    func onEnd() {
        update {
            $0(\._from, nil)
            $0(\._to, .zero)
        }
    }

    fileprivate func onPan(_ info: PanInfo?) {
        guard active, let info else { return }
        update { $0(\._to, info.current) }
    }

    fileprivate var subscriptions = Set<AnyCancellable>()
}

struct AddingPathService {
    let toolbar: ToolbarStore
    let viewport: ViewportService
    let store: AddingPathStore

    var from: Point2? { store.from }
    var to: Point2 { store.to }
    var active: Bool { store.active }

    func segment(edgeCase: PathEdge.Case) -> PathSegment? {
        guard let from = store.from else { return nil }
        let edge: PathEdge
        switch edgeCase {
        case .arc:
            let radius = from.distance(to: to) / 2
            edge = .arc(.init(radius: .init(radius, radius), rotation: .zero, largeArc: false, sweep: false))
        case .bezier:
            let mid = from.midPoint(to: to)
            let offset = mid.offset(to: to)
            edge = .bezier(.init(control0: mid + offset.normalLeft / 2, control1: mid + offset.normalRight / 2))
        case .line:
            edge = .line(.init())
        }
        return .init(from: from, to: to, edge: edge)
    }

    func subscribe(to multipleTouch: MultipleTouchModel) {
        multipleTouch.$panInfo
            .sink { self.store.onPan($0) }
            .store(in: &store.subscriptions)
    }

    var edgeCase: PathEdge.Case {
        guard case let .addPath(addPath) = toolbar.mode else { return .line }
        return addPath.edgeCase
    }

    var segment: PathSegment? {
        segment(edgeCase: edgeCase)
    }

    var addingPath: Path? {
        guard let segment else { return nil }
        let segmentInWorld = segment.applying(viewport.toWorld)
        let fromNode = PathNode(position: segmentInWorld.from)
        let toNode = PathNode(position: segmentInWorld.to)
        let pairs: Path.PairMap = [
            fromNode.id: .init(fromNode, segmentInWorld.edge),
            toNode.id: .init(toNode, .line(.init())),
        ]
        return .init(pairs: pairs, isClosed: false)
    }
}

struct AddingPath: View {
    @Selected var addingPath = global.addingPath.addingPath

    var body: some View {
        if let addingPath {
            PathView(path: addingPath, focusedPart: nil)
                .environmentObject(PathViewModel())
//            SUPath { addingPathSegment.append(to: &$0) }
//                .stroke(.blue, style: .init(lineWidth: 4))
//            HStack {
//                Color.clear
//                    .popover(isPresented: .constant(true)) {
//                        VStack {
//                            ControlGroup {
//                                Button("Arc", systemImage: "circle") { }
//                                Button("Bezier", systemImage: "point.bottomleft.forward.to.point.topright.scurvepath") { }
//                                Button("Line", systemImage: "chart.xyaxis.line") { }
//                            } label: {
//                                Text("Type")
//                            }.controlGroupStyle(.navigation)
//                        }
//                        .padding()
//                    }
//            }
//            .border(.red)
//            .frame(width: 1, height: 1)
//            .position(position)
        }
    }
}
