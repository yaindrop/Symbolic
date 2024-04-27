import Combine
import Foundation
import SwiftUI

// MARK: - PathUpdater

class PathUpdater: ObservableObject {
    let activePathModel: ActivePathModel
    let viewport: Viewport

    func activePathHandle(node id: UUID, with positionInView: Point2, pending: Bool = false) {
        guard let activePath else { return }
        let position = positionInView.applying(viewport.info.viewToWorld)
        let event = DocumentEvent(inPath: activePath.id, updateNode: activePath.node(id: id)!.with(position: position))
        (pending ? pendingEventSubject : eventSubject).send(event)
    }

    func activePathHandle(edge fromNodeId: UUID, with bezierInView: PathBezier, pending: Bool = false) {
        guard let activePath else { return }
        let bezier = bezierInView.applying(viewport.info.viewToWorld)
        let event = DocumentEvent(inPath: activePath.id, updateEdgeFrom: fromNodeId, .Bezier(bezier))
        (pending ? pendingEventSubject : eventSubject).send(event)
    }

    func activePathHandle(edge fromNodeId: UUID, with arcInView: PathArc, pending: Bool = false) {
        guard let activePath else { return }
        let arc = arcInView.applying(viewport.info.viewToWorld)
        let event = DocumentEvent(inPath: activePath.id, updateEdgeFrom: fromNodeId, .Arc(arc))
        (pending ? pendingEventSubject : eventSubject).send(event)
    }

    func activePathPanel(node id: UUID, with position: Point2, pending: Bool = false) {
        guard let activePath else { return }
        let event = DocumentEvent(inPath: activePath.id, updateNode: activePath.node(id: id)!.with(position: position))
        (pending ? pendingEventSubject : eventSubject).send(event)
    }

    func activePathPanel(edge fromNodeId: UUID, with bezier: PathBezier, pending: Bool = false) {
        guard let activePath else { return }
        let event = DocumentEvent(inPath: activePath.id, updateEdgeFrom: fromNodeId, .Bezier(bezier))
        (pending ? pendingEventSubject : eventSubject).send(event)
    }

    func activePathPanel(edge fromNodeId: UUID, with arc: PathArc, pending: Bool = false) {
        guard let activePath else { return }
        let event = DocumentEvent(inPath: activePath.id, updateEdgeFrom: fromNodeId, .Arc(arc))
        (pending ? pendingEventSubject : eventSubject).send(event)
    }

    func onEvent(_ callback: @escaping (DocumentEvent) -> Void) {
        eventSubject.sink { value in callback(value) }.store(in: &subscriptions)
    }

    func onPendingEvent(_ callback: @escaping (DocumentEvent) -> Void) {
        pendingEventSubject.sink { value in callback(value) }.store(in: &subscriptions)
    }

    init(activePathModel: ActivePathModel, viewport: Viewport) {
        self.activePathModel = activePathModel
        self.viewport = viewport
    }
    
    // MARK: private

    private var subscriptions = Set<AnyCancellable>()
    private var eventSubject = PassthroughSubject<DocumentEvent, Never>()
    private var pendingEventSubject = PassthroughSubject<DocumentEvent, Never>()

    private var activePath: Path? { activePathModel.activePath }
}
