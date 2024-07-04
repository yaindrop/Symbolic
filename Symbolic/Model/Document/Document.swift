import SwiftUI

// MARK: - Document

struct Document: Codable {
    let id: UUID
    var events: [DocumentEvent] = []

    init(events: [DocumentEvent] = []) {
        id = .init()
        self.events = events
    }

    init(from svg: String) {
        id = .init()
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
