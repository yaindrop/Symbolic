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

        let symbolId = UUID()
        events.append(.init(kind: .single(.symbol(.init(symbolId: symbolId, .create(.init(origin: .init(200, 300), size: .init(squared: 1000), grids: []))))), action: nil))
        for path in paths {
            events.append(.init(
                kind: .single(.path(.init(pathId: .init(), .create(.init(path: path))))),
                action: .path(.load(.init(symbolId: symbolId, pathIds: .init(repeating: .init(), count: paths.count).map { _ in UUID() }, paths: paths)))
            ))
        }
    }
}

extension Document: EquatableBy {
    var equatableBy: some Equatable { events.map { $0.id } }
}
