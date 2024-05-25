import Foundation
import SwiftUI

// reference: https://www.w3.org/TR/SVG11/implnote.html#ArcParameterizationAlternatives
struct ArcCenterParams: ReflectedStringConvertible {
    let center: Point2
    let radius: CGSize
    let rotation: Angle
    let startAngle: Angle
    let deltaAngle: Angle

    func with(startAngle: Angle) -> Self { .init(center: center, radius: radius, rotation: rotation, startAngle: startAngle, deltaAngle: deltaAngle) }
    func with(deltaAngle: Angle) -> Self { .init(center: center, radius: radius, rotation: rotation, startAngle: startAngle, deltaAngle: deltaAngle) }

    var endAngle: Angle { startAngle + deltaAngle }
    var clockwise: Bool { deltaAngle < .zero }
    var transform: CGAffineTransform { CGAffineTransform.identity.centered(at: center) { $0.rotated(by: rotation.radians).scaledBy(x: radius.width, y: radius.height) } }

    func position(paramT: Scalar) -> Point2 {
        let t = (0 ... 1).clamp(paramT)
        let phi = rotation.radians, sinPhi = sin(phi), cosPhi = cos(phi)
        let theta = (startAngle + deltaAngle * t).radians
        let sinTheta = sin(theta), cosTheta = cos(theta)
        let mat = Matrix2((cosPhi, -sinPhi), (sinPhi, cosPhi))
        return center + mat * Vector2(radius.width * cosTheta, radius.height * sinTheta)
    }

    var endpointParams: ArcEndpointParams {
        let phi = rotation.radians, sinPhi = sin(phi), cosPhi = cos(phi)
        let theta1 = startAngle.radians, sinTheta1 = sin(theta1), cosTheta1 = cos(theta1)
        let theta2 = endAngle.radians, sinTheta2 = sin(theta2), cosTheta2 = cos(theta2)
        let mat = Matrix2((cosPhi, -sinPhi), (sinPhi, cosPhi))
        let from = center + mat * Vector2(radius.width * cosTheta1, radius.height * sinTheta1)
        let to = center + mat * Vector2(radius.width * cosTheta2, radius.height * sinTheta2)
        let largeArc = abs(deltaAngle.radians) > Scalar.pi
        let sweep = deltaAngle > .zero
        return .init(from: from, to: to, radius: radius, rotation: rotation, largeArc: largeArc, sweep: sweep)
    }
}

struct ArcEndpointParams: ReflectedStringConvertible {
    let from: Point2
    let to: Point2
    let radius: CGSize
    let rotation: Angle
    let largeArc: Bool
    let sweep: Bool

    var centerParams: ArcCenterParams {
        let a = Vector2(from), b = Vector2(to)
        let phi = rotation.radians, sinPhi = sin(phi), cosPhi = cos(phi)

        var rx = abs(radius.width), ry = abs(radius.height)
        guard rx != 0 && ry != 0 else {
            logError("Radius cannot be 0")
            return .init(center: from, radius: .zero, rotation: rotation, startAngle: .zero, deltaAngle: .zero)
        }

        // F.6.5.1
        let xy1Prime = Matrix2((cosPhi, sinPhi), (-sinPhi, cosPhi)) * (a - b) / 2
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
            logError("Start point can not be same as end point")
            return .init(center: from, radius: .zero, rotation: rotation, startAngle: .zero, deltaAngle: .zero)
        }

        let coefficientSign: Scalar = largeArc == sweep ? -1 : 1
        let coefficient = coefficientSign * sqrt(abs((rx * rx * ry * ry - sumOfSquare) / sumOfSquare))

        let cPrime = coefficient * Vector2(rx * y1p / ry, -ry * x1p / rx)
        let cxp = cPrime.dx, cyp = cPrime.dy

        // F.6.5.3
        let c = Matrix2((cosPhi, -sinPhi), (sinPhi, cosPhi)) * cPrime + (a + b) / 2

        // F.6.5.5
        let u = Vector2(1, 0)
        let v = Vector2((x1p - cxp) / rx, (y1p - cyp) / ry)
        let w = Vector2((-x1p - cxp) / rx, (-y1p - cyp) / ry)
        let theta1 = u.radian(to: v)

        // F.6.5.6
        var deltaTheta = fmod(v.radian(to: w), 2 * Scalar.pi)
        if !sweep && deltaTheta > 0 {
            deltaTheta -= 2 * Scalar.pi
        } else if sweep && deltaTheta < 0 {
            deltaTheta += 2 * Scalar.pi
        }
        return .init(center: Point2(c), radius: CGSize(rx, ry), rotation: rotation, startAngle: Angle(radians: theta1), deltaAngle: Angle(radians: deltaTheta))
    }
}
