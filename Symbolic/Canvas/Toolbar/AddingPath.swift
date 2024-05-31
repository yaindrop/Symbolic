import Combine
import Foundation
import SwiftUI

class AddingPathStore: Store {
    @Trackable var from: Point2? = nil
    @Trackable var to: Point2 = .zero

    var active: Bool { from != nil }

    fileprivate func update(from: Point2?) {
        update {
            $0(\._from, from)
            $0(\._to, from ?? .zero)
        }
    }

    fileprivate func update(to: Point2) {
        update {
            $0(\._to, to)
        }
    }
}

struct AddingPathService {
    let toolbar: ToolbarStore
    let viewport: ViewportService
    let grid: GridStore
    let store: AddingPathStore

    var from: Point2? { store.from }
    var to: Point2 { store.to }
    var active: Bool { store.active }

    var segment: PathSegment? {
        guard let from = store.from else { return nil }
        let mid = from.midPoint(to: to)
        let offset = mid.offset(to: to)
        return .init(edge: .init(control0: from.offset(to: mid + offset.normalLeft / 2), control1: to.offset(to: mid + offset.normalRight / 2)), from: from, to: to)
    }

    var addingPath: Path? {
        guard let segment else { return nil }
        let segmentInWorld = segment.applying(viewport.toWorld)
        let fromNode = PathNode(id: UUID(), position: segmentInWorld.from)
        let toNode = PathNode(id: UUID(), position: segmentInWorld.to)
        let pairs: Path.PairMap = [
            fromNode.id: .init(fromNode, segmentInWorld.edge),
            toNode.id: .init(toNode, .init()),
        ]
        return .init(id: UUID(), pairs: pairs, isClosed: false)
    }

    func onStart(from: Point2) {
        store.update(from: grid.snap(from))
    }

    func onEnd() {
        store.update(from: nil)
    }

    func onDrag(_ info: PanInfo?) {
        guard active, let info else { return }
        store.update(to: grid.snap(info.current))
    }

    func cancel() {
        store.update(from: nil)
    }
}

struct AddingPathView: View {
    @Selected var addingPath = global.addingPath.addingPath

    var body: some View {
        if let addingPath {
            PathView(path: addingPath, focusedPart: nil)
                .environmentObject(PathViewModel())
        }
    }
}