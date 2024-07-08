import SwiftUI

protocol Snappable {
    func snap(_ point: Point2) -> Point2
}

extension Snappable {
    func snapped(_ point: Point2) -> Bool {
        point == snap(point)
    }
}

struct Grid: Equatable {
    var kind: Kind
    var tintColor: Color = .gray
    var `case`: Case {
        switch kind {
        case .cartesian: .cartesian
        case .isometric: .isometric
        case .radial: .radial
        }
    }

    struct Cartesian: Equatable {
        var interval: Scalar
    }

    struct Isometric: Equatable {
        var interval: Scalar, angle0: Angle, angle1: Angle
    }

    struct Radial: Equatable {
        var radialSize: Scalar, angularDivision: Int
    }

    enum Case { case cartesian, isometric, radial }

    enum Kind: Equatable {
        case cartesian(Cartesian)
        case isometric(Isometric)
        case radial(Radial)
    }
}

extension Grid.Cartesian: Animatable {
    var animatableData: Scalar.AnimatableData {
        get { interval.animatableData }
        set { interval.animatableData = newValue }
    }
}

extension Grid.Isometric: Animatable {
    var animatableData: AnimatablePair<Scalar, AnimatablePair<Scalar, Scalar>> {
        get { .init(interval, .init(angle0.radians, angle1.radians)) }
        set {
            interval = newValue.first
            angle0 = .radians(newValue.second.first)
            angle1 = .radians(newValue.second.second)
        }
    }
}

// MARK: - Snappable

extension Grid.Cartesian: Snappable {
    func snap(_ point: Point2) -> Point2 {
        let x = round(point.x / interval) * interval
        let y = round(point.y / interval) * interval
        return .init(x: x, y: y)
    }
}

extension Grid: Snappable {
    func snap(_ point: Point2) -> Point2 {
        switch kind {
        case let .cartesian(cartesian): cartesian.snap(point)
        default: point
        }
    }
}
