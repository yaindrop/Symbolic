import Combine
import Foundation
import SwiftUI

typealias PathMap = OrderedMap<UUID, Path>

// MARK: - PathModel

@Observable
class PathModel {
    var pathMap = PathMap()

    var paths: [Path] { pathMap.values }

    fileprivate var pathMapUpdater: (() -> Void) -> Void { { $0() } }
}

// MARK: - PendingPathModel

@Observable
class PendingPathModel {
    var pendingEvent: DocumentEvent? { didSet { pendingEventSubject.send(pendingEvent) } }
    fileprivate(set) var pathMap = PathMap()

    var hasPendingEvent: Bool { pendingEvent != nil }

    var paths: [Path] { pathMap.values }

    fileprivate var pathMapUpdater: (() -> Void) -> Void { { $0() } }

    @ObservationIgnored fileprivate var loading = false
    @ObservationIgnored fileprivate var subscriptions = Set<AnyCancellable>()
    @ObservationIgnored fileprivate var pendingEventSubject = PassthroughSubject<DocumentEvent?, Never>()
}

// MARK: - PathInteractor

struct PathInteractor {
    let model: PathModel
    let pendingModel: PendingPathModel

    func add(path: Path) {
        let _r = tracer.range("Add path"); defer { _r() }
        guard path.count > 1 else { return }
        guard targetPathMap[path.id] == nil else { return }
        targetPathMap[path.id] = path.cloned
    }

    func remove(pathId: UUID) {
        let _r = tracer.range("Remove path"); defer { _r() }
        guard targetPathMap[pathId] != nil else { return }
        targetPathMap.removeValue(forKey: pathId)
    }

    func update(path: Path) {
        let _r = tracer.range("Update path"); defer { _r() }
        guard path.count > 1 else {
            remove(pathId: path.id)
            return
        }
        guard targetPathMap[path.id] != nil else { return }
        targetPathMap[path.id] = path.cloned
    }

    func clear() {
        let _r = tracer.range("Clear paths"); defer { _r() }
        targetPathMap.removeAll()
    }

    func subscribe() {
        pendingModel.pendingEventSubject.sink { self.loadPendingEvent($0) }.store(in: &pendingModel.subscriptions)
    }

    // MARK: private

    private var targetPathMap: PathMap {
        get { pendingModel.loading ? pendingModel.pathMap : model.pathMap }
        nonmutating set {
            if pendingModel.loading { pendingModel.pathMap = newValue } else { model.pathMap = newValue }
        }
    }

    private var targetPathMapUpdater: (() -> Void) -> Void {
        pendingModel.loading ? pendingModel.pathMapUpdater : model.pathMapUpdater
    }

    private func loadPendingEvent(_ event: DocumentEvent?) {
        let _r = tracer.range("Path load pending event"); defer { _r() }
        guard let event else { return }
        pendingModel.loading = true
        defer { pendingModel.loading = false }
        pendingModel.pathMap = model.pathMap.cloned
        targetPathMapUpdater {
            loadEvent(event)
        }
    }
}

// MARK: - PathModel load events

extension PathInteractor {
    func loadDocument(_ document: Document) {
        let _r = tracer.range("Path load document"); defer { _r() }
        targetPathMapUpdater {
            clear()
            for event in document.events {
                loadEvent(event)
            }
        }
    }

    func loadEvent(_ event: DocumentEvent) {
        switch event.kind {
        case let .pathEvent(pathEvent):
            loadEvent(pathEvent)
        case let .compoundEvent(compoundEvent):
            compoundEvent.events.forEach {
                switch $0 {
                case let .pathEvent(pathEvent):
                    loadEvent(pathEvent)
                }
            }
        }
    }

    func loadEvent(_ event: PathEvent) {
        let _r = tracer.range("Path load event"); defer { _r() }
        switch event {
        case let .create(create):
            loadPathEvent(create)
        case let .delete(delete):
            loadPathEvent(delete)
        case let .update(update):
            loadPathEvent(update)
        }
    }

    func loadPathEvent(_ event: PathEvent.Create) {
        add(path: event.path)
    }

    func loadPathEvent(_ event: PathEvent.Delete) {
        remove(pathId: event.pathId)
    }

    func loadPathEvent(_ event: PathEvent.Update) {
        switch event.kind {
        case let .move(move):
            loadPathUpdate(pathId: event.pathId, move)
        case let .breakAfter(breakAfter):
            loadPathUpdate(pathId: event.pathId, breakAfter)
        case let .breakUntil(breakUntil):
            loadPathUpdate(pathId: event.pathId, breakUntil)
        case let .edgeUpdate(edgeUpdate):
            loadPathUpdate(pathId: event.pathId, edgeUpdate)
        case let .nodeCreate(nodeCreate):
            loadPathUpdate(pathId: event.pathId, nodeCreate)
        case let .nodeDelete(nodeDelete):
            loadPathUpdate(pathId: event.pathId, nodeDelete)
        case let .nodeUpdate(nodeUpdate):
            loadPathUpdate(pathId: event.pathId, nodeUpdate)
        }
    }

    func loadPathUpdate(pathId: UUID, _ move: PathEvent.Update.Move) {
        guard let path = targetPathMap[pathId] else { return }
        path.update(move: move)
        update(path: path)
    }

    func loadPathUpdate(pathId: UUID, _ breakAfter: PathEvent.Update.BreakAfter) {
        guard let path = targetPathMap[pathId] else { return }
        path.update(breakAfter: breakAfter)
        update(path: path)
    }

    func loadPathUpdate(pathId: UUID, _ breakUntil: PathEvent.Update.BreakUntil) {
        guard let path = targetPathMap[pathId] else { return }
        path.update(breakUntil: breakUntil)
        update(path: path)
    }

    func loadPathUpdate(pathId: UUID, _ edgeUpdate: PathEvent.Update.EdgeUpdate) {
        guard let path = targetPathMap[pathId] else { return }
        path.update(edgeUpdate: edgeUpdate)
        update(path: path)
    }

    func loadPathUpdate(pathId: UUID, _ nodeCreate: PathEvent.Update.NodeCreate) {
        guard let path = targetPathMap[pathId] else { return }
        path.update(nodeCreate: nodeCreate)
        update(path: path)
    }

    func loadPathUpdate(pathId: UUID, _ nodeDelete: PathEvent.Update.NodeDelete) {
        guard let path = targetPathMap[pathId] else { return }
        path.update(nodeDelete: nodeDelete)
        update(path: path)
    }

    func loadPathUpdate(pathId: UUID, _ nodeUpdate: PathEvent.Update.NodeUpdate) {
        guard let path = targetPathMap[pathId] else { return }
        path.update(nodeUpdate: nodeUpdate)
        update(path: path)
    }
}

extension PathModel {
    func hitTest(worldPosition: Point2) -> Path? {
        paths.first { p in p.hitPath.contains(worldPosition) }
    }
}
