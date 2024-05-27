import Foundation

extension SVGPathCommand.ArcTo {
    func approximate(current: Point2) -> [SVGPathCommand] {
        var commands: [SVGPathCommand] = []
        let params = toEndpointParams(current: current).centerParams
        SUPath {
            $0.addRelativeArc(center: params.center, radius: 1, startAngle: params.startAngle, delta: params.deltaAngle, transform: params.transform)
        }
        .forEach {
            switch $0 {
            case .closeSubpath: break
            case let .curve(to, control1, control2):
                commands.append(.bezierTo(.init(control0: control1, control1: control2, position: to)))
            case let .line(to):
                commands.append(.lineTo(.init(position: to)))
            case .move: break
            case let .quadCurve(to, control):
                commands.append(.quadraticBezierTo(.init(control: control, position: to)))
            }
        }
        return commands
    }
}

extension SVGPathCommand.BezierTo {
    func toEdge(current: Point2) -> PathEdge {
        .init(control0: current.offset(to: control0), control1: position.offset(to: control1))
    }
}

extension SVGPathCommand {
    func toEdge(current: Point2) -> PathEdge {
        switch self {
        case .arcTo:
            logError("Arc should have been approximated")
            return .init()
        case let .bezierTo(bezierTo):
            return bezierTo.toEdge(current: current)
        case .lineTo:
            return .init()
        case let .quadraticBezierTo(quadraticBezierTo):
            let bezierTo = quadraticBezierTo.toCubic(current: current)
            return bezierTo.toEdge(current: current)
        }
    }
}

extension Path {
    convenience init(from svgPath: SVGPath) {
        var pairs = PairMap()
        var arcApproximatedCommands: [SVGPathCommand] = []

        var current = svgPath.initial
        for command in svgPath.commands {
            if case let .arcTo(arcTo) = command {
                arcApproximatedCommands += arcTo.approximate(current: current)
            } else {
                arcApproximatedCommands.append(command)
            }
            current = command.position
        }

        current = svgPath.initial
        for command in arcApproximatedCommands {
            let node = PathNode(id: UUID(), position: current)
            pairs.append((node.id, .init(node, command.toEdge(current: current))))
            current = command.position
        }

        if svgPath.initial != svgPath.last {
            let node = PathNode(id: UUID(), position: svgPath.last)
            pairs.append((node.id, .init(node, .init())))
        }
        self.init(id: UUID(), pairs: pairs, isClosed: svgPath.isClosed)
    }
}
