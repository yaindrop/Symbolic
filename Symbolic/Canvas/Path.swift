//
//  Path.swift
//  Symbolic
//
//  Created by Yaindrop on 2024/4/11.
//

import Foundation
import SwiftUI

struct PathLine {
    func draw(path: inout SwiftUI.Path, to: CGPoint) {
        path.addLine(to: to)
    }
}

struct PathArc {
    var radius: CGSize
    var rotation: Angle
    var largeArc: Bool
    var sweep: Bool

    func toParam(from: CGPoint, to: CGPoint) -> ArcEndpointParam {
        ArcEndpointParam(from: from, to: to, radius: radius, rotation: rotation, largeArc: largeArc, sweep: sweep)
    }

    func draw(path: inout SwiftUI.Path, to: CGPoint) {
        if let from = path.currentPoint, let p = toParam(from: from, to: to).toCenterParam() {
            print(p)
            path.addArc(center: p.center, radius: 1, startAngle: p.startAngle, endAngle: p.endAngle, clockwise: p.clockwise, transform: p.transform)
        }
    }
}

struct PathBezier {
    var control0: CGPoint
    var control1: CGPoint
    func draw(path: inout SwiftUI.Path, to: CGPoint) {
        path.addCurve(to: to, control1: control0, control2: control1)
    }
}

enum PathAction {
    case Line(PathLine)
    case Arc(PathArc)
    case Bezier(PathBezier)
    func draw(path: inout SwiftUI.Path, to: CGPoint) {
        switch self {
        case let .Line(l):
            l.draw(path: &path, to: to)
        case let .Arc(a):
            a.draw(path: &path, to: to)
        case let .Bezier(b):
            b.draw(path: &path, to: to)
        }
    }
}

struct PathVertex: Identifiable {
    let id = UUID()
    var position: CGPoint
}

struct Path: Identifiable {
    let id = UUID()
    var pairs: Array<(PathVertex, PathAction)> = []

    func draw(path: inout SwiftUI.Path) {
        print(self)
        guard let first = pairs.first else { return }
        path.move(to: first.0.position)
        for i in 0 ..< pairs.count {
            let action = pairs[i].1
            let nextIndex = i + 1 == pairs.count ? 0 : i + 1
            let nextVertex = pairs[nextIndex].0
            action.draw(path: &path, to: nextVertex.position)
        }
    }
}

func foo() -> Array<Path> {
    var result: Array<Path> = []
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
               L 50 100
               Z" fill="none" stroke="black" stroke-width="2" />
    </svg>
    """.data(using: .utf8)!
    let parser = XMLParser(data: data)
    let delegate = SVGParserDelegate()
    parser.delegate = delegate
    delegate.onPath { result.append(Path(from: $0)) }
    parser.parse()
    return result
}
