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

extension PathAction {
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
    init(from svgPath: SVGPath) {
        var pairs: [PathVertexActionPair] = []
        var current = svgPath.initial
        for command in svgPath.commands {
            pairs.append((PathVertex(position: current), PathAction(from: command, at: current)))
            current = command.position
        }
        if svgPath.initial != svgPath.last {
            pairs.append((PathVertex(position: svgPath.last), .Line(PathLine())))
        }
        id = UUID()
        self.pairs = pairs
        isClosed = svgPath.isClosed
    }
}
