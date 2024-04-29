import Foundation

extension PathEdge.Arc {
    init(from command: SVGPathCommand.ArcTo) {
        self.init(radius: command.radius, rotation: command.rotation, largeArc: command.largeArc, sweep: command.sweep)
    }
}

extension PathEdge.Bezier {
    init(from command: SVGPathCommand.BezierTo) {
        self.init(control0: command.control0, control1: command.control1)
    }
}

extension PathEdge {
    init(from command: SVGPathCommand, at current: Point2) {
        switch command {
        case let .arcTo(c):
            self = .arc(Arc(from: c))
        case let .bezierTo(c):
            self = .bezier(Bezier(from: c))
        case .lineTo:
            self = .line(Line())
        case let .quadraticBezierTo(c):
            self = .bezier(Bezier(from: c.toCubic(current: current)))
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
            pairs.append((PathNode(position: svgPath.last), .line(PathEdge.Line())))
        }
        self.init(pairs: pairs, isClosed: svgPath.isClosed)
    }
}
