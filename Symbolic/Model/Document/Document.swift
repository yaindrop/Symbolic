import SwiftUI

// MARK: - Document

struct Document: Encodable {
    var events: [DocumentEvent] = []

    init(events: [DocumentEvent] = []) {
        self.events = events
    }

    init(from svg: String) {
        guard let svgData = svg.data(using: .utf8) else {
            events = []
            return
        }
        var paths: [Path] = []
        let delegate = SVGParserDelegate()
        delegate.onPath { paths.append(Path(from: $0)) }

        let parser = XMLParser(data: svgData)
        parser.delegate = delegate
        parser.parse()

        events.append(.init(kind: .single(.path(.create(.init(paths: paths)))), action: .path(.load(.init(paths: paths)))))
    }
}

extension Document: EquatableBy {
    var equatableBy: some Equatable { events.map { $0.id } }
}

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
        let _r = tracer.range("Document set"); defer { _r() }
        withStoreUpdating {
            store.update(pendingEvent: nil)
            store.update(activeDocument: document)
        }
    }

    func sendEvent(_ event: DocumentEvent) {
        let _r = tracer.range("Document send event"); defer { _r() }
        if store.pendingEvent == nil {
            withAnimation(.fast) {
                store.update(activeDocument: .init(events: activeDocument.events + [event]))
            }
        } else {
            withAnimation(.fast) {
                store.update(pendingEvent: nil)
                store.update(activeDocument: .init(events: activeDocument.events + [event]))
            }
        }
    }

    func setPendingEvent(_ event: DocumentEvent?) {
        let _r = tracer.range("Document set pending event"); defer { _r() }
        store.update(pendingEvent: event)
    }

    func undo() {
        guard undoable else { return }
        var events = store.activeDocument.events
        events.removeLast()
        setDocument(.init(events: events))
    }
}

let fooSvg = """
<svg width="300" height="200" xmlns="http://www.w3.org/2000/svg">
  <!-- Define the complex path with different commands -->
  <path d="M 0 0 L 50 50 L 100 0 Z
           M 50 100
           C 60 110, 90 140, 100 150
           S 180 120, 150 100
           Q 160 180, 150 150
           T 200 150
           A 50 70 40 0 0 250 150
           Z" fill="none" stroke="black" stroke-width="2" />
</svg>
"""
