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
    var rotation: Angle = .zero
    var largeArc: Bool = false
    var sweep: Bool = false

    struct CenterParam {
        var center: CGPoint
        var radius: CGSize
        var startAngle: Angle
        var endAngle: Angle
    }

    // reference: https://www.w3.org/TR/SVG11/implnote.html#ArcConversionEndpointToCenter
    func toCenterParam(from: CGVector, to: CGVector) -> CenterParam? {
        let phi = rotation.radians, sinPhi = sin(phi), cosPhi = cos(phi)

        var rx = abs(radius.width), ry = abs(radius.height)
        guard rx != 0 && ry != 0 else {
            print("Radius cannot be 0")
            return nil
        }

        // F.6.5.1
        let xy1Prime = Matrix2D(a: cosPhi, b: sinPhi, c: -sinPhi, d: cosPhi) * (from - to) / 2
        let x1p = xy1Prime.dx, y1p = xy1Prime.dy

        // F.6.6 Correction of out-of-range radii
        let lambda = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry)
        if lambda > 1 {
            rx = rx * sqrt(lambda)
            ry = ry * sqrt(lambda)
        }

        // F.6.5.2
        let sumOfSquare = rx * rx * y1p * y1p + ry * ry * x1p * x1p
        guard sumOfSquare != 0 else {
            print("Start point can not be same as end point")
            return nil
        }

        let coefficientSign: CGFloat = largeArc == sweep ? -1 : 1
        let coefficient = coefficientSign * sqrt(abs((rx * rx * ry * ry - sumOfSquare) / sumOfSquare))

        let cPrime = coefficient * CGVector(dx: rx * y1p / ry, dy: -ry * x1p / rx)
        let cxp = cPrime.dx, cyp = cPrime.dy

        // F.6.5.3
        let c = Matrix2D(a: cosPhi, b: sinPhi, c: -sinPhi, d: cosPhi) * CGVector(dx: cxp, dy: cyp) + (from + to) / 2

        let u = CGVector(dx: 1, dy: 0)
        let v = CGVector(dx: (x1p - cxp) / rx, dy: (y1p - cyp) / ry)
        let w = CGVector(dx: (-x1p - cxp) / rx, dy: (-y1p - cyp) / ry)

        // F.6.5.5
        let theta1 = u.radian(v)

        // F.6.5.6
        let deltaTheta = fmod(v.radian(w), 2 * CGFloat.pi) - (sweep ? 0 : 2 * CGFloat.pi)
        let theta2 = fmod(theta1 + deltaTheta, 2 * CGFloat.pi)

        return CenterParam(center: CGPoint(from: c), radius: CGSize(width: rx, height: ry), startAngle: Angle(radians: theta1), endAngle: Angle(radians: theta2))
    }

    func draw(path: inout SwiftUI.Path, to: CGPoint) {
        if let p = toCenterParam(from: CGVector(from: path.currentPoint!), to: CGVector(from: to)) {
            print(p)
            let t = CGAffineTransform.identity.scaledBy(x: p.radius.width, y: p.radius.height, around: p.center)
            path.addArc(center: p.center, radius: 1, startAngle: p.startAngle, endAngle: p.endAngle, clockwise: true, transform: t)
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
               A 50 70 0 0 1 250 150
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
