import Combine
import Foundation
import SwiftUI

typealias PathMap = OrderedMap<UUID, Path>

// MARK: - PathModel

class PathModel: ObservableObject {
    @Published fileprivate(set) var pathMap = PathMap()

    var paths: [Path] { pathMap.values }

    fileprivate var updatingPathMap: PathMap?

    fileprivate func updatePathMap(_ pathMap: inout PathMap, _ updater: () -> Void) {
        updatingPathMap = pathMap
        defer { updatingPathMap = nil }
        updater()
        pathMap = updatingPathMap!
    }
}

// MARK: - PendingPathModel

class PendingPathModel: ObservableObject {
    @Published var pendingEvent: DocumentEvent?
    @Published fileprivate(set) var pathMap = PathMap()

    var hasPendingEvent: Bool { pendingEvent != nil }

    var paths: [Path] { pathMap.values }

    fileprivate var loading = false
    fileprivate var subscriptions = Set<AnyCancellable>()
}

// MARK: - EnablePathInteractor

protocol EnablePathInteractor {
    var pathModel: PathModel { get }
    var pendingPathModel: PendingPathModel { get }
}

extension EnablePathInteractor {
    var pathInteractor: PathInteractor { .init(model: pathModel, pendingModel: pendingPathModel) }
}

// MARK: - PathInteractor

struct PathInteractor {
    let model: PathModel
    let pendingModel: PendingPathModel

    func add(path: Path) {
        guard path.count > 1 else { return }
        guard updatingPathMap[path.id] == nil else { return }
        updatingPathMap[path.id] = path
    }

    func remove(pathId: UUID) {
        guard updatingPathMap[pathId] != nil else { return }
        updatingPathMap.removeValue(forKey: pathId)
    }

    func update(path: Path) {
        guard path.count > 1 else {
            remove(pathId: path.id)
            return
        }
        guard updatingPathMap[path.id] != nil else { return }
        updatingPathMap[path.id] = path
    }

    func clear() {
        updatingPathMap.removeAll()
    }

    func subscribe() {
        pendingModel.$pendingEvent.sink { self.loadPendingEvent($0) }.store(in: &pendingModel.subscriptions)
    }

    private func loadPendingEvent(_ event: DocumentEvent?) {
        guard let event else { return }
        pendingModel.loading = true
        defer { pendingModel.loading = false }
        pendingModel.pathMap = model.pathMap.cloned
        model.updatePathMap(&targetPathMap) {
            loadEvent(event)
        }
    }
}

// MARK: - PathModel load events

extension PathInteractor {
    private var targetPathMap: PathMap {
        get { pendingModel.loading ? pendingModel.pathMap : model.pathMap }
        nonmutating set {
            if pendingModel.loading { pendingModel.pathMap = newValue } else { model.pathMap = newValue }
        }
    }

    private var updatingPathMap: PathMap {
        get {
            if let updatingPathMap = model.updatingPathMap { updatingPathMap } else { targetPathMap }
        }
        nonmutating set {
            if model.updatingPathMap != nil { model.updatingPathMap = newValue } else { targetPathMap = newValue }
        }
    }

    func loadDocument(_ document: Document) {
        model.updatePathMap(&targetPathMap) {
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

    func loadPathUpdate(pathId: UUID, _ breakAfter: PathEvent.Update.BreakAfter) {
        guard let path = updatingPathMap[pathId] else { return }
        path.update(breakAfter: breakAfter)
        update(path: path)
    }

    func loadPathUpdate(pathId: UUID, _ breakUntil: PathEvent.Update.BreakUntil) {
        guard let path = updatingPathMap[pathId] else { return }
        path.update(breakUntil: breakUntil)
        update(path: path)
    }

    func loadPathUpdate(pathId: UUID, _ edgeUpdate: PathEvent.Update.EdgeUpdate) {
        guard let path = updatingPathMap[pathId] else { return }
        path.update(edgeUpdate: edgeUpdate)
        update(path: path)
    }

    func loadPathUpdate(pathId: UUID, _ nodeCreate: PathEvent.Update.NodeCreate) {
        guard let path = updatingPathMap[pathId] else { return }
        path.update(nodeCreate: nodeCreate)
        update(path: path)
    }

    func loadPathUpdate(pathId: UUID, _ nodeDelete: PathEvent.Update.NodeDelete) {
        guard let path = updatingPathMap[pathId] else { return }
        path.update(nodeDelete: nodeDelete)
        update(path: path)
    }

    func loadPathUpdate(pathId: UUID, _ nodeUpdate: PathEvent.Update.NodeUpdate) {
        guard let path = updatingPathMap[pathId] else { return }
        path.update(nodeUpdate: nodeUpdate)
        update(path: path)
    }
}

extension PathModel {
    func hitTest(worldPosition: Point2) -> Path? {
        paths.first { p in p.hitPath.contains(worldPosition) }
    }
}
