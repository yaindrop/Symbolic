import Foundation

private let subtracer = tracer.tagged("DocumentService")

// MARK: - DocumentStore

class DocumentStore: Store {
    @Trackable var activeDocument: Document = .init()
    @Trackable var pendingEvent: DocumentEvent?
}

private extension DocumentStore {
    func update(activeDocument: Document) {
        update { $0(\._activeDocument, activeDocument) }
    }

    func update(pendingEvent: DocumentEvent?) {
        update { $0(\._pendingEvent, pendingEvent) }
    }
}

// MARK: - DocumentService

struct DocumentService {
    let store: DocumentStore
}

// MARK: selectors

extension DocumentService {
    var activeDocument: Document { store.activeDocument }

    var undoable: Bool {
        guard let last = store.activeDocument.events.last else { return false }
        if case let .path(p) = last.action {
            if case .load = p {
                return false
            }
        }
        return true
    }
}

// MARK: actions

extension DocumentService {
    func setDocument(_ document: Document) {
        let _r = subtracer.range("set"); defer { _r() }
        withStoreUpdating {
            store.update(pendingEvent: nil)
            store.update(activeDocument: document)
        }
    }

    func sendEvent(_ event: DocumentEvent) {
        let _r = subtracer.range("send event"); defer { _r() }
        if store.pendingEvent == nil {
            withStoreUpdating(configs: .init(animation: .fast)) {
                store.update(activeDocument: .init(events: activeDocument.events + [event]))
            }
        } else {
            withStoreUpdating(configs: .init(animation: .fast)) {
                store.update(pendingEvent: nil)
                store.update(activeDocument: .init(events: activeDocument.events + [event]))
            }
        }
    }

    func setPendingEvent(_ event: DocumentEvent?) {
        let _r = subtracer.range("set pending event"); defer { _r() }
        store.update(pendingEvent: event)
    }

    func undo() {
        guard undoable else { return }
        var events = store.activeDocument.events
        events.removeLast()
        setDocument(.init(events: events))
    }
}
