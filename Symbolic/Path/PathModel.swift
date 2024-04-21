//
//  PathModel.swift
//  Symbolic
//
//  Created by Yaindrop on 2024/4/21.
//

import Foundation

class PathModel: ObservableObject {
    @Published var pathIds: Array<UUID> = []

    var pathIdToPath: [UUID: Path] = [:]
    var vertexIdToVertex: [UUID: PathVertex] = [:]

    init() {
    }

    func addPath(_ path: Path) {
        pathIds.append(path.id)
        pathIdToPath[path.id] = path
    }
}

func foo(model: PathModel) {
    let data = """
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
    """.data(using: .utf8)!
    let parser = XMLParser(data: data)
    let delegate = SVGParserDelegate()
    parser.delegate = delegate
    delegate.onPath { model.addPath(Path(from: $0)) }
    parser.parse()
}
