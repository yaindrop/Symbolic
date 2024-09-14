import SwiftUI

// MARK: - Grid

struct Grid: Equatable {
    var tintColor: CGColor = UIColor.gray.cgColor
    var kind: Kind

    struct Cartesian: Equatable {
        var interval: Scalar
    }

    struct Isometric: Equatable {
        var interval: Scalar, angle0: Angle, angle1: Angle
    }

    struct Radial: Equatable {
        var interval: Scalar, angularDivisions: Int
    }

    enum Kind: Equatable {
        case cartesian(Cartesian)
        case isometric(Isometric)
        case radial(Radial)
    }
}

extension Grid {
    enum Case { case cartesian, isometric, radial }

    var `case`: Case {
        switch kind {
        case .cartesian: .cartesian
        case .isometric: .isometric
        case .radial: .radial
        }
    }

    var cartesian: Cartesian? { if case let .cartesian(kind) = kind { kind } else { nil }}

    var isometric: Isometric? { if case let .isometric(kind) = kind { kind } else { nil }}

    var radial: Radial? { if case let .radial(kind) = kind { kind } else { nil }}
}

func adjusted(from interval: Scalar, target: Scalar) -> Scalar {
    interval * pow(2, max(0, ceil(log2(target / interval))))
}

// MARK: - Animatable

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

protocol Snappable {
    func snap(_ point: Point2) -> Point2
}

extension Snappable {
    func snapped(_ point: Point2) -> Bool {
        point == snap(point)
    }

    func snappedOffset(_ point: Point2, offset: Vector2) -> Vector2 {
        point.offset(to: snap(point + offset))
    }
}

extension Grid.Cartesian: Snappable {
    func snap(_ point: Point2) -> Point2 {
        let horizontalLine = horizontalLineSet.line(closestTo: point)
        let verticalLine = verticalLineSet.line(closestTo: point)
        return horizontalLine.intersection(with: verticalLine)!
    }
}

extension Grid.Isometric: Snappable {
    func snap(_ point: Point2) -> Point2 {
        let verticalLine = verticalLineSet.line(closestTo: point)
        let perspectiveLine = perspectiveLineSet0.line(closestTo: point)
        return perspectiveLine.intersection(with: verticalLine)!
    }
}

extension Grid.Radial: Snappable {
    func snap(_ point: Point2) -> Point2 {
        point
    }
}

extension Grid: Snappable {
    var impl: Snappable {
        switch kind {
        case let .cartesian(cartesian): cartesian
        case let .isometric(isometric): isometric
        case let .radial(radial): radial
        }
    }

    func snap(_ point: Point2) -> Point2 {
        impl.snap(point)
    }
}
