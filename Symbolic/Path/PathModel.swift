import Combine
import Foundation
import SwiftUI

typealias PathMap = OrderedMap<UUID, Path>

// MARK: - PathModel

class PathModel: Store {
    @Trackable var pathMap = PathMap()

    var paths: [Path] { pathMap.values }

    fileprivate func update(pathMap: PathMap) {
        update { $0(\._pathMap, pathMap) }
    }
}

// MARK: - PendingPathModel

class PendingPathModel: Store {
    @Trackable var pendingEvent: DocumentEvent?
    @Trackable var pathMap = PathMap()

    var hasPendingEvent: Bool { pendingEvent != nil }

    var paths: [Path] { pathMap.values }

    fileprivate var loading = false
    fileprivate var subscriptions = Set<AnyCancellable>()
    fileprivate var pendingEventSubject = PassthroughSubject<DocumentEvent?, Never>()

    func update(pendingEvent: DocumentEvent?) {
        pendingEventSubject.send(pendingEvent)
        update { $0(\._pendingEvent, pendingEvent) }
    }

    fileprivate func update(pathMap: PathMap) {
        update { $0(\._pathMap, pathMap) }
    }
}

// MARK: - PathService

struct PathService {
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
            if pendingModel.loading { pendingModel.update(pathMap: newValue) } else { model.update(pathMap: newValue) }
        }
    }

    private func loadPendingEvent(_ event: DocumentEvent?) {
        let _r = tracer.range("Path load pending event"); defer { _r() }
        guard let event else { return }
        pendingModel.loading = true
        defer { pendingModel.loading = false }
        withStoreUpdating {
            pendingModel.update(pathMap: model.pathMap.cloned)
            loadEvent(event)
        }
    }
}

// MARK: - PathModel load events

extension PathService {
    func loadDocument(_ document: Document) {
        let _r = tracer.range("Path load document", type: .intent); defer { _r() }
        withStoreUpdating {
            clear()
            for event in document.events {
                loadEvent(event)
            }
        }
    }

    func loadEvent(_ event: DocumentEvent) {
        let _r = tracer.range("Path load document event \(event.id)", type: .intent); defer { _r() }
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
