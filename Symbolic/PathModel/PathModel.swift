import Combine
import Foundation
import SwiftUI

// MARK: - PathModel

class PathModel: ObservableObject {
    @Published fileprivate(set) var pathMap = OrderedMap<UUID, Path>()

    var paths: [Path] { pathMap.values }
}

// MARK: - PendingPathModel

class PendingPathModel: ObservableObject {
    @Published var pendingEvent: DocumentEvent?
    @Published fileprivate(set) var pathMap = OrderedMap<UUID, Path>()

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

    private var targetPathMap: OrderedMap<UUID, Path> {
        get { pendingModel.loading ? pendingModel.pathMap : model.pathMap }
        nonmutating set {
            if pendingModel.loading { pendingModel.pathMap = newValue } else { model.pathMap = newValue }
        }
    }

    func add(path: Path) {
        guard path.count > 1 else { return }
        guard targetPathMap[path.id] == nil else { return }
        targetPathMap[path.id] = path
    }

    func remove(pathId: UUID) {
        guard targetPathMap[pathId] != nil else { return }
        targetPathMap.removeValue(forKey: pathId)
    }

    func update(path: Path) {
        guard path.count > 1 else {
            remove(pathId: path.id)
            return
        }
        guard targetPathMap[path.id] != nil else { return }
        targetPathMap[path.id] = path
    }

    func clear() {
        targetPathMap.removeAll()
    }

    func subscribe() {
        pendingModel.$pendingEvent.sink { self.loadPendingEvent($0) }.store(in: &pendingModel.subscriptions)
    }

    private func loadPendingEvent(_ event: DocumentEvent?) {
        guard let event else { return }
        pendingModel.loading = true
        defer { pendingModel.loading = false }
        pendingModel.pathMap = model.pathMap
        loadEvent(event)
    }
}

// MARK: - PathModel load events

extension PathInteractor {
    func loadDocument(_ document: Document) {
        for event in document.events {
            loadEvent(event)
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
        let start = Date.now
        defer { print("\tLoad event takes \(Date.now.timeIntervalSince(start))") }
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
        guard let path = targetPathMap[pathId] else { return }
        update(path: path.with(breakAfter: breakAfter))
    }

    func loadPathUpdate(pathId: UUID, _ breakUntil: PathEvent.Update.BreakUntil) {
        guard let path = targetPathMap[pathId] else { return }
        update(path: path.with(breakUntil: breakUntil))
    }

    func loadPathUpdate(pathId: UUID, _ edgeUpdate: PathEvent.Update.EdgeUpdate) {
        guard let path = targetPathMap[pathId] else { return }
        update(path: path.with(edgeUpdate: edgeUpdate))
    }

    func loadPathUpdate(pathId: UUID, _ nodeCreate: PathEvent.Update.NodeCreate) {
        guard let path = targetPathMap[pathId] else { return }
        update(path: path.with(nodeCreate: nodeCreate))
    }

    func loadPathUpdate(pathId: UUID, _ nodeDelete: PathEvent.Update.NodeDelete) {
        guard let path = targetPathMap[pathId] else { return }
        update(path: path.with(nodeDelete: nodeDelete))
    }

    func loadPathUpdate(pathId: UUID, _ nodeUpdate: PathEvent.Update.NodeUpdate) {
        guard let path = targetPathMap[pathId] else { return }
        update(path: path.with(nodeUpdate: nodeUpdate))
    }
}

extension PathModel {
    func hitTest(worldPosition: Point2) -> Path? {
        paths.first { p in p.hitPath.contains(worldPosition) }
    }
}
