import Combine
import Foundation

struct Document: Equatable {
    let events: [DocumentEvent]

    static func == (lhs: Document, rhs: Document) -> Bool {
        lhs.events.count == rhs.events.count && lhs.events.enumerated().allSatisfy { i, e in e.id == rhs.events[i].id }
    }

    init(events: [DocumentEvent] = []) {
        self.events = events
    }

    init(from svg: String) {
        guard let svgData = svg.data(using: .utf8) else {
            events = []
            return
        }
        let parser = XMLParser(data: svgData)
        let delegate = SVGParserDelegate()
        var events: [DocumentEvent] = []
        parser.delegate = delegate
        delegate.onPath {
            let path = Path(from: $0)
            let pathEvent: PathEvent = .create(.init(path: path))
            let event = DocumentEvent(kind: .pathEvent(pathEvent), action: .pathAction(.load(.init(path: path))))
            events.append(event)
        }
        parser.parse()
        self.events = events
    }
}

class DocumentStore: Store {
    @Trackable var activeDocument: Document = Document()

    func setDocument(_ document: Document) {
        let _r = tracer.range("Document set"); defer { _r() }
        update { $0(\._activeDocument, document) }
    }

    func sendEvent(_ event: DocumentEvent) {
        let _r = tracer.range("Document send event"); defer { _r() }
        update { $0(\._activeDocument, Document(events: activeDocument.events + [event])) }
    }
}

struct DocumentService {
    let store: DocumentStore

    var activeDocument: Document { store.activeDocument }

    var undoable: Bool {
        guard let last = store.activeDocument.events.last else { return false }
        if case let .pathAction(p) = last.action {
            if case .load = p {
                return false
            }
        }
        return true
    }

    func undo() {
        guard undoable else { return }
        var events = store.activeDocument.events
        events.removeLast()
        store.setDocument(.init(events: events))
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
