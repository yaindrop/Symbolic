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
        let pathEvents: [PathEvent] = paths.map { .init(pathId: .init(), .create(.init(path: $0))) }
        let pathIds: [UUID] = pathEvents.map { $0.pathIds.first! }
        events.append(.init(kind: .single(.symbol(.init(symbolId: symbolId, .create(.init(origin: .init(200, 300), size: .init(squared: 1000), grids: []))))), action: nil))
        for pathEvent in pathEvents {
            events.append(.init(
                kind: .single(.path(pathEvent)),
                action: .path(.load(.init(symbolId: symbolId, pathIds: pathIds, paths: paths)))
            ))
        }
        events.append(.init(kind: .single(.symbol(.init(symbolId: symbolId, .setMembers(.init(members: pathIds))))), action: nil))
    }
}

extension Document: EquatableBy {
    var equatableBy: some Equatable { events.map { $0.id } }
}
