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
    let radius: CGSize
    let rotation: Angle
    let largeArc: Bool
    let sweep: Bool

    func toParam(from: CGPoint, to: CGPoint) -> ArcEndpointParam {
        ArcEndpointParam(from: from, to: to, radius: radius, rotation: rotation, largeArc: largeArc, sweep: sweep)
    }

    func draw(path: inout SwiftUI.Path, to: CGPoint) {
        guard let from = path.currentPoint else { return }
        var endPointparam = toParam(from: from, to: to)
        guard let param = endPointparam.centerParam?.value else { return }
        print(param)
        path.addArc(center: param.center, radius: 1, startAngle: param.startAngle, endAngle: param.endAngle, clockwise: param.clockwise, transform: param.transform)
    }
}

struct PathBezier {
    let control0: CGPoint
    let control1: CGPoint
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
    let pairs: Array<(PathVertex, PathAction)>
    let isClosed: Bool

    var vertices: Array<PathVertex> { pairs.map { $0.0 } }

    var segments: Array<(PathVertex, PathAction, PathVertex)> {
        pairs.enumerated().compactMap { i, pair in
            let (vertex, action) = pair
            let nextIndex = i + 1 == pairs.count ? 0 : i + 1
            let nextVertex = pairs[nextIndex].0
            if !isClosed && nextIndex == 0 {
                return nil
            }
            return (vertex, action, nextVertex)
        }
    }

    func draw(path: inout SwiftUI.Path) {
        print(self)
        guard let first = pairs.first else { return }
        path.move(to: first.0.position)
        for (_, a, next) in segments {
            a.draw(path: &path, to: next.position)
        }
        if isClosed {
            path.closeSubpath()
        }
    }

    func vertexViews() -> some View {
        ForEach(vertices, id: \.id) { v in
            Circle().fill(.blue.opacity(0.5)).frame(width: 4, height: 4).position(v.position)
        }
    }

    func controlViews() -> some View {
        let arcs = segments.compactMap { v, a, n in if case let .Arc(arc) = a { (v, arc, n) } else { nil } }
        let beziers = segments.compactMap { v, a, n in if case let .Bezier(bezier) = a { (v, bezier, n) } else { nil } }
        return Group {
            ForEach(arcs, id: \.0.id) { v, arc, n in
                var endPointParam = arc.toParam(from: v.position, to: n.position)
                let param = endPointParam.centerParam!.value
                SwiftUI.Path { p in
                    p.move(to: .zero)
                    p.addLine(to: CGPoint(x: param.radius.width, y: 0))
                    p.move(to: .zero)
                    p.addLine(to: CGPoint(x: 0, y: param.radius.height))
                }
                .stroke(.yellow.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [2]))
                .frame(width: param.radius.width, height: param.radius.height)
                .rotationEffect(param.rotation, anchor: UnitPoint(x: 0, y: 0))
                .position(param.center + CGVector(dx: param.radius.width / 2, dy: param.radius.height / 2))
                Circle().fill(.yellow).frame(width: 4, height: 4).position(param.center)
                Circle()
                    .fill(.brown.opacity(0.5))
                    .frame(width: 1, height: 1)
                    .scaleEffect(x: param.radius.width * 2, y: param.radius.height * 2)
                    .rotationEffect(param.rotation)
                    .position(param.center)
            }
            ForEach(beziers, id: \.0.id) { v, bezier, n in
                SwiftUI.Path { p in
                    p.move(to: v.position)
                    p.addLine(to: bezier.control0)
                }.stroke(.green.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [2]))
                SwiftUI.Path { p in
                    p.move(to: n.position)
                    p.addLine(to: bezier.control1)
                }.stroke(.orange.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [2]))
                Circle()
                    .fill(.green)
                    .frame(width: 4, height: 4)
                    .position(bezier.control0)
                Circle()
                    .fill(.orange)
                    .frame(width: 4, height: 4)
                    .position(bezier.control1)
            }
        }

//        ForEach(segments, id: \.0.id) { curr, a, next in
//            if let arc = .Arc(a) {
//                guard let p = arc.toParam(from: curr.position, to: next.position).toCenterParam() else { Circle() }
//                Circle().fill(.yellow.opacity(0.5)).frame(width: 4, height: 4).position(p.center)
//                Circle().fill(.white.opacity(0.5)).frame(width: 1, height: 1).position(p.center).transformEffect(p.transform)
//            } else if let bezier = .Bezier(a) {
//                Circle().fill(.green.opacity(0.5)).frame(width: 4, height: 4).position(bezier.control0)
//                Circle().fill(.green.opacity(0.5)).frame(width: 4, height: 4).position(bezier.control1)
//            } else {
//                Circle()
//            }
//        }
    }
}

class PathModel: ObservableObject {
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
