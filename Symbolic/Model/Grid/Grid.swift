import SwiftUI

// MARK: - Grid

struct Grid: Equatable, Codable {
    var tintColor: CodableColor = .init(uiColor: .gray)
    var kind: Kind

    struct Cartesian: Equatable, Codable {
        var interval: Scalar
    }

    struct Isometric: Equatable, Codable {
        var interval: Scalar, angle0: Angle, angle1: Angle
    }

    struct Radial: Equatable, Codable {
        var interval: Scalar, angularDivisions: Int
    }

    enum Kind: Equatable, Codable {
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
}

func adjusted(from interval: Scalar, target: Scalar) -> Scalar {
    interval * pow(2, max(0, ceil(log2(target / interval))))
}

// MARK: - Cartesian

extension Grid.Cartesian {
    var verticalLineSet: ParallelLineSet { .vertical(interval: interval) }

    var horizontalLineSet: ParallelLineSet { .horizontal(interval: interval) }

    func lineSets(target: Scalar? = nil) -> [ParallelLineSet] {
        var interval = interval
        if let target {
            interval = adjusted(from: interval, target: target)
        }
        return [.vertical(interval: interval), .horizontal(interval: interval)]
    }
}

// MARK: - Isometric

extension Grid.Isometric {
    var intercept: Scalar { interval * abs(tan(angle0.radians) + tan(-angle1.radians)) }

    var interval0: Scalar { intercept * cos(angle0.radians) }

    var interval1: Scalar { intercept * cos(angle1.radians) }

    var verticalLineSet: ParallelLineSet { .vertical(interval: interval) }

    var perspectiveLineSet0: ParallelLineSet { .init(interval: interval0, angle: angle0) }

    var perspectiveLineSet1: ParallelLineSet { .init(interval: interval0, angle: angle0) }

    func lineSets(target: Scalar? = nil) -> [ParallelLineSet] {
        var interval = interval, perspectiveInterval0 = interval0, perspectiveInterval1 = interval1
        if let target {
            interval = adjusted(from: interval, target: target)
            perspectiveInterval0 = adjusted(from: interval0, target: target)
            perspectiveInterval1 = adjusted(from: interval1, target: target)
        }
        if intercept.nearlyEqual(0, epsilon: 0.1) {
            return [.init(interval: interval, angle: angle0), .vertical(interval: interval)]
        } else {
            return [.init(interval: perspectiveInterval0, angle: angle0), .init(interval: perspectiveInterval1, angle: angle1), .vertical(interval: interval)]
        }
    }
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
