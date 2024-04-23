import Foundation

extension PathArc {
    init(from command: SVGPathCommandArcTo) {
        self.init(radius: command.radius, rotation: command.rotation, largeArc: command.largeArc, sweep: command.sweep)
    }
}

extension PathBezier {
    init(from command: SVGPathCommandBezierTo) {
        self.init(control0: command.control0, control1: command.control1)
    }
}

extension PathEdge {
    init(from command: SVGPathCommand, at current: Point2) {
        switch command {
        case let .ArcTo(c):
            self = .Arc(PathArc(from: c))
        case let .BezierTo(c):
            self = .Bezier(PathBezier(from: c))
        case .LineTo:
            self = .Line(PathLine())
        case let .QuadraticBezierTo(c):
            self = .Bezier(PathBezier(from: c.toCubic(current: current)))
        }
    }
}

extension Path {
    convenience init(from svgPath: SVGPath) {
        var pairs: [NodeEdgePair] = []
        var current = svgPath.initial
        for command in svgPath.commands {
            pairs.append((PathNode(position: current), PathEdge(from: command, at: current)))
            current = command.position
        }
        if svgPath.initial != svgPath.last {
            pairs.append((PathNode(position: svgPath.last), .Line(PathLine())))
        }
        self.init(pairs: pairs, isClosed: svgPath.isClosed)
    }
}
