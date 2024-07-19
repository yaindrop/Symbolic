import SwiftUI

// MARK: - AddingPathStore

class AddingPathStore: Store {
    @Trackable var points: [Point2] = []
}

private extension AddingPathStore {
    func update(points: [Point2]) {
        update { $0(\._points, points) }
    }
}

// MARK: - AddingPathService

struct AddingPathService {
    let store: AddingPathStore
    let viewport: ViewportService
    let grid: GridStore
}

// MARK: selectors

extension AddingPathService {
    var from: Point2? { store.points.first }
    var to: Point2 { store.points.last ?? .zero }
    var active: Bool { !store.points.isEmpty }

    var segment: PathSegment? {
        guard let from else { return nil }
        let mid = from.midPoint(to: to)
        let offset = mid.offset(to: to)
        return .init(from: from, to: to, fromControlOut: from.offset(to: mid + offset.normalLeft / 2), toControlIn: to.offset(to: mid + offset.normalRight / 2))
    }

    var addingPath: Path? {
        guard let segment else { return nil }
        let segmentInWorld = segment.applying(viewport.toWorld)
        let fromNode = PathNode(position: segmentInWorld.from, controlOut: segmentInWorld.fromControlOut)
        let toNode = PathNode(position: segmentInWorld.to, controlIn: segmentInWorld.toControlIn)
        let nodeMap = Path.NodeMap(values: [fromNode, toNode]) { _ in UUID() }
        return .init(id: UUID(), nodeMap: nodeMap, isClosed: false)
    }

    var polyline: Path? {
        guard store.points.count > 1 else { return nil }
        let polyline = Polyline(points: store.points.map { $0.applying(viewport.toWorld) })
        let nodes = polyline.fit(error: 1)
        return .init(id: UUID(), nodeMap: .init(values: nodes) { _ in UUID() }, isClosed: false)
    }
}

// MARK: actions

extension AddingPathService {
    func onStart(from: Point2) {
        store.update(points: [from])
    }

    func onEnd() {
        store.update(points: [])
    }

    func onDrag(_ info: PanInfo?) {
        guard active, let info else { return }
//        let snapped = grid.snap(info.current)
        store.update(points: store.points.cloned { $0.append(info.current) })
    }

    func cancel() {
        store.update(points: [])
    }
}

// MARK: - AddingPathView

struct AddingPathView: View, TracedView, SelectorHolder {
    class Selector: SelectorBase {
        @Selected({ global.addingPath.polyline }) var polyline
        @Selected({ global.viewport.toView }) var toView
    }

    @SelectorWrapper var selector

    var body: some View { trace {
        setupSelector {
            content
        }
    } }
}

private extension AddingPathView {
    @ViewBuilder var content: some View {
        if let polyline = selector.polyline {
            SUPath { polyline.append(to: &$0) }
                .stroke(Color(UIColor.label), style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
                .allowsHitTesting(false)
                .transformEffect(selector.toView)
//                .id(path.id)
        }
    }
}
