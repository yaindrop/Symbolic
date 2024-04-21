//
//  ArcParam.swift
//  Symbolic
//
//  Created by Yaindrop on 2024/4/16.
//

import Foundation
import SwiftUI

// reference: https://www.w3.org/TR/SVG11/implnote.html#ArcParameterizationAlternatives
struct ArcCenterParam {
    let center: CGPoint
    let radius: CGSize
    let rotation: Angle
    let startAngle: Angle
    let deltaAngle: Angle

    var endAngle: Angle { startAngle + deltaAngle }
    var clockwise: Bool { deltaAngle < Angle.zero }
    var transform: CGAffineTransform { CGAffineTransform.identity.centered(at: center) { $0.rotated(by: rotation.radians).scaledBy(x: radius.width, y: radius.height) } }

    lazy var endpointParam: Box<ArcEndpointParam> = {
        let phi = rotation.radians, sinPhi = sin(phi), cosPhi = cos(phi)
        let theta1 = startAngle.radians, sinTheta1 = sin(theta1), cosTheta1 = cos(theta1)
        let theta2 = endAngle.radians, sinTheta2 = sin(theta2), cosTheta2 = cos(theta2)
        let mat = Matrix2(a: cosPhi, b: -sinPhi, c: sinPhi, d: cosPhi)
        let from = center + mat * CGVector(dx: radius.width * cosTheta1, dy: radius.height * sinTheta1)
        let to = center + mat * CGVector(dx: radius.width * cosTheta2, dy: radius.height * sinTheta2)
        let largeArc = abs(deltaAngle.radians) > CGFloat.pi
        let sweep = deltaAngle.radians > 0
        return Box(ArcEndpointParam(from: from, to: to, radius: radius, rotation: rotation, largeArc: largeArc, sweep: sweep))
    }()
}

struct ArcEndpointParam {
    let from: CGPoint
    let to: CGPoint
    let radius: CGSize
    let rotation: Angle
    let largeArc: Bool
    let sweep: Bool

    lazy var centerParam: Box<ArcCenterParam>? = {
        let a = CGVector(from: from), b = CGVector(from: to)
        let phi = rotation.radians, sinPhi = sin(phi), cosPhi = cos(phi)

        var rx = abs(radius.width), ry = abs(radius.height)
        guard rx != 0 && ry != 0 else {
            print("Radius cannot be 0")
            return nil
        }

        // F.6.5.1
        let xy1Prime = Matrix2(a: cosPhi, b: sinPhi, c: -sinPhi, d: cosPhi) * (a - b) / 2
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
        let c = Matrix2(a: cosPhi, b: -sinPhi, c: sinPhi, d: cosPhi) * cPrime + (a + b) / 2

        // F.6.5.5
        let u = CGVector(dx: 1, dy: 0)
        let v = CGVector(dx: (x1p - cxp) / rx, dy: (y1p - cyp) / ry)
        let w = CGVector(dx: (-x1p - cxp) / rx, dy: (-y1p - cyp) / ry)
        let theta1 = u.radian(v)

        // F.6.5.6
        var deltaTheta = fmod(v.radian(w), 2 * CGFloat.pi)
        if !sweep && deltaTheta > 0 {
            deltaTheta -= 2 * CGFloat.pi
        } else if sweep && deltaTheta < 0 {
            deltaTheta += 2 * CGFloat.pi
        }
        return Box(ArcCenterParam(center: CGPoint(from: c), radius: CGSize(width: rx, height: ry), rotation: rotation, startAngle: Angle(radians: theta1), deltaAngle: Angle(radians: deltaTheta)))
    }()
}
