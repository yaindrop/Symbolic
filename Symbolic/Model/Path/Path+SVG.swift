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
    func toControls(current: Point2) -> (cubicOut: Vector2, cubicIn: Vector2) {
        (cubicOut: current.offset(to: control0), cubicIn: position.offset(to: control1))
    }
}

extension SVGPathCommand {
    func toControls(current: Point2) -> (cubicOut: Vector2, cubicIn: Vector2) {
        switch self {
        case .arcTo:
            logError("Arc should have been approximated")
            return (.zero, .zero)
        case let .bezierTo(bezierTo):
            return bezierTo.toControls(current: current)
        case .lineTo:
            return (.zero, .zero)
        case let .quadraticBezierTo(quadraticBezierTo):
            let bezierTo = quadraticBezierTo.toCubic(current: current)
            return bezierTo.toControls(current: current)
        }
    }
}

extension Path {
    convenience init(from svgPath: SVGPath) {
        var approximatedCommands: [SVGPathCommand] = []

        var current = svgPath.initial
        for command in svgPath.commands {
            if case let .arcTo(arcTo) = command {
                approximatedCommands += arcTo.approximate(current: current)
            } else {
                approximatedCommands.append(command)
            }
            current = command.position
        }

        var nodes: [PathNode] = []
        current = svgPath.initial
        var prevCubicIn: Vector2?
        for command in approximatedCommands {
            let (cubicOut, cubicIn) = command.toControls(current: current)
            nodes.append(.init(position: current, cubicIn: prevCubicIn ?? .zero, cubicOut: cubicOut))
            current = command.position
            prevCubicIn = cubicIn
        }

        if svgPath.initial != svgPath.last {
            nodes.append(.init(position: svgPath.last))
        }

        let nodeMap = NodeMap(values: nodes) { _ in UUID() }
        self.init(id: UUID(), nodeMap: nodeMap, isClosed: svgPath.isClosed)
    }
}
