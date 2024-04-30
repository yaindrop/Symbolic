import Foundation
import SwiftUI

// MARK: - SVGPathCommand

fileprivate protocol SVGPathCommandImpl: CustomStringConvertible {
    var position: Point2 { get }
}

enum SVGPathCommand {
    struct LineTo: SVGPathCommandImpl {
        let position: Point2

        public var description: String { return "L \(position.x) \(position.y)" }
    }

    struct ArcTo: SVGPathCommandImpl {
        let radius: CGSize, rotation: Angle, largeArc: Bool, sweep: Bool, position: Point2

        public var description: String { return "A \(radius.width) \(radius.height) \(rotation) \(largeArc ? 1 : 0) \(sweep ? 1 : 0) \(position.x) \(position.y)" }
    }

    struct BezierTo: SVGPathCommandImpl {
        let control0: Point2, control1: Point2, position: Point2

        func toQuadratic(current: Point2) -> QuadraticBezierTo? {
            let quadraticControl0 = current + current.deltaVector(to: control0) * 3 / 2
            let quadraticControl1 = position + position.deltaVector(to: control1) * 3 / 2
            guard quadraticControl0 == quadraticControl1 else { return nil }
            return QuadraticBezierTo(control: quadraticControl0, position: position)
        }

        public var description: String { return "C \(control0.x) \(control0.y) \(control1.x) \(control1.y) \(position.x) \(position.y)" }
    }

    struct QuadraticBezierTo: SVGPathCommandImpl {
        let control: Point2, position: Point2

        func toCubic(current: Point2) -> BezierTo {
            let control0 = current + (current.deltaVector(to: control)) * 2 / 3
            let control1 = position + (position.deltaVector(to: control)) * 2 / 3
            return BezierTo(control0: control0, control1: control1, position: position)
        }

        public var description: String { return "Q \(control.x) \(control.y) \(position.x) \(position.y)" }
    }

    case lineTo(LineTo)
    case arcTo(ArcTo)
    case bezierTo(BezierTo)
    case quadraticBezierTo(QuadraticBezierTo)
}

extension SVGPathCommand: SVGPathCommandImpl {
    fileprivate var impl: SVGPathCommandImpl {
        switch self {
        case let .arcTo(c): c
        case let .bezierTo(c): c
        case let .lineTo(c): c
        case let .quadraticBezierTo(c): c
        }
    }

    var position: Point2 { impl.position }
    public var description: String { impl.description }
}

struct SVGPath {
    var initial: Point2 = Point2.zero
    var commands: [SVGPathCommand] = []
    var isClosed: Bool = false

    var isEmpty: Bool { commands.isEmpty }

    var last: Point2 {
        guard let last = commands.last else { return Point2.zero }
        return last.position
    }
}

// MARK: - SVGPathParser

enum SVGPathParserError: Error {
    case invalidCommand(String)
    case invalidParameters(String)
}

// reference https://www.w3.org/TR/SVG11/paths.html
class SVGPathParser {
    var paths: [SVGPath] = []

    init(data: String) {
        scanner = Scanner(string: data.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines))
    }

    func parse() throws {
        while !scanner.isAtEnd {
            try scan()
        }
        appendPath(withClosed: false)
    }

    // MARK: private

    private static let allCommands = "MmLlHhVvCcSsQqTtAaZz"
    private static let commandSet: Set<Character> = Set(allCommands)
    private static let commandCharacterSet = CharacterSet(charactersIn: allCommands)
    private static let separatorCharacterSet = CharacterSet(charactersIn: " ,")

    private let scanner: Scanner

    // parsing path
    private var path: SVGPath = SVGPath()

    // parsing command context
    private var command: Character = "M"
    private var isRelative: Bool { command.isLowercase }
    private var parameters: [CGFloat] = []

    // MARK: scan

    private func scan() throws {
        command = try scanCommand()
        parameters = try scanParameters()
        switch command.uppercased() {
        case "M": try parseMoveTo()
        case "Z": try parseClosePath()
        case "L": try parseLineTo()
        case "H": try parseHorizontalLineTo()
        case "V": try parseVerticalLineTo()
        case "C": try parseCurveTo()
        case "S": try parseSmoothCurveTo()
        case "Q": try parseQuadraticBezierCurveTo()
        case "T": try parseSmoothQuadraticBezierCurveTo()
        case "A": try parseEllipticalArc()
        default: break
        }
    }

    private func scanCommand() throws -> Character {
        guard let command = scanner.scanCharacter(), SVGPathParser.commandSet.contains(command) else {
            throw SVGPathParserError.invalidCommand("Expect command at \(scanner.currentIndex)")
        }
        return command
    }

    private func scanParameters() throws -> [CGFloat] {
        guard let parametersStr = scanner.scanUpToCharacters(from: SVGPathParser.commandCharacterSet) else { return [] }
        let parameterStrList = parametersStr.components(separatedBy: SVGPathParser.separatorCharacterSet).filter { !$0.isEmpty }
        let parameters = parameterStrList.compactMap { Double($0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)) }.map { CGFloat($0) }
        guard parameters.count == parameterStrList.count else {
            throw SVGPathParserError.invalidParameters("Nonnumerical parameter in \(parametersStr)")
        }
        return parameters
    }

    // MARK: append result

    private func appendCommand(_ command: SVGPathCommand) {
        path.commands.append(command)
    }

    private func appendPath(withClosed isClosed: Bool, moveTo: Point2 = Point2.zero) {
        if !path.isEmpty {
            path.isClosed = isClosed
            paths.append(path)
        }
        path = SVGPath(initial: moveTo)
    }

    // MARK: parameter getter

    private func parameterGroups(of n: Int) -> [[CGFloat]]? {
        guard parameters.count % n == 0 else { return nil }
        var groups: [[CGFloat]] = []
        for i in stride(from: 0, to: parameters.count, by: n) {
            groups.append(Array(parameters[i ..< i + n]))
        }
        return groups
    }

    private func positionOf(x: CGFloat, y: CGFloat) -> Point2 {
        if isRelative {
            return path.last + Vector2(x, y)
        } else {
            return Point2(x, y)
        }
    }

    private func flagOf(value: CGFloat) -> Bool? {
        if value == 0 {
            return false
        } else if value == 1 {
            return true
        }
        return nil
    }

    // MARK: parse commands

    private func parseMoveTo() throws {
        guard let groups = parameterGroups(of: 2), let firstGroup = groups.first else {
            throw SVGPathParserError.invalidParameters("Invalid move-to parameters \(parameters)")
        }
        let moveToPosition = positionOf(x: firstGroup[0], y: firstGroup[1])
        appendPath(withClosed: false, moveTo: moveToPosition)
        for group in groups.dropFirst() {
            let lineToPosition = positionOf(x: group[0], y: group[1])
            appendCommand(.lineTo(SVGPathCommand.LineTo(position: lineToPosition)))
        }
    }

    private func parseClosePath() throws {
        guard parameters.isEmpty else {
            throw SVGPathParserError.invalidParameters("Close path command cannot have parameters \(parameters)")
        }
        appendPath(withClosed: true)
    }

    private func parseLineTo() throws {
        guard let groups = parameterGroups(of: 2) else {
            throw SVGPathParserError.invalidParameters("Invalid line-to parameters \(parameters)")
        }
        for group in groups {
            let position = positionOf(x: group[0], y: group[1])
            appendCommand(.lineTo(SVGPathCommand.LineTo(position: position)))
        }
    }

    private func parseHorizontalLineTo() throws {
        guard !parameters.isEmpty else {
            throw SVGPathParserError.invalidParameters("Invalid horizontal line-to parameters \(parameters)")
        }
        for x in parameters {
            let position = positionOf(x: x, y: 0)
            appendCommand(.lineTo(SVGPathCommand.LineTo(position: position)))
        }
    }

    private func parseVerticalLineTo() throws {
        guard !parameters.isEmpty else {
            throw SVGPathParserError.invalidParameters("Invalid vertical line-to parameters \(parameters)")
        }
        for y in parameters {
            let position = positionOf(x: 0, y: y)
            appendCommand(.lineTo(SVGPathCommand.LineTo(position: position)))
        }
    }

    private func parseCurveTo() throws {
        guard let groups = parameterGroups(of: 6) else {
            throw SVGPathParserError.invalidParameters("Invalid curve-to parameters \(parameters)")
        }
        for group in groups {
            let control0 = positionOf(x: group[0], y: group[1]),
                control1 = positionOf(x: group[2], y: group[3]),
                position = positionOf(x: group[4], y: group[5])
            appendCommand(.bezierTo(SVGPathCommand.BezierTo(control0: control0, control1: control1, position: position)))
        }
    }

    private func parseSmoothCurveTo() throws {
        guard let groups = parameterGroups(of: 4) else {
            throw SVGPathParserError.invalidParameters("Invalid smooth curve-to parameters \(parameters)")
        }
        var control0 = path.last
        if let lastCommand = path.commands.last, case let .bezierTo(lastBezier) = lastCommand {
            control0 = lastBezier.position + lastBezier.control1.deltaVector(to: lastBezier.position)
        }
        for group in groups {
            let control1 = positionOf(x: group[0], y: group[1]),
                position = positionOf(x: group[2], y: group[3])
            appendCommand(.bezierTo(SVGPathCommand.BezierTo(control0: control0, control1: control1, position: position)))
        }
    }

    private func parseQuadraticBezierCurveTo() throws {
        guard let groups = parameterGroups(of: 4) else {
            throw SVGPathParserError.invalidParameters("Invalid quadratic bezier curve-to parameters \(parameters)")
        }
        for group in groups {
            let control = positionOf(x: group[0], y: group[1]),
                position = positionOf(x: group[2], y: group[3])
            appendCommand(.quadraticBezierTo(SVGPathCommand.QuadraticBezierTo(control: control, position: position)))
        }
    }

    private func parseSmoothQuadraticBezierCurveTo() throws {
        guard let groups = parameterGroups(of: 2) else {
            throw SVGPathParserError.invalidParameters("Invalid smooth quadratic bezier curve-to parameters \(parameters)")
        }
        var control = path.last
        if let lastCommand = path.commands.last, case let .quadraticBezierTo(lastQuadraticBezier) = lastCommand {
            control = lastQuadraticBezier.position + lastQuadraticBezier.control.deltaVector(to: lastQuadraticBezier.position)
        }
        for group in groups {
            let position = positionOf(x: group[0], y: group[1])
            appendCommand(.quadraticBezierTo(SVGPathCommand.QuadraticBezierTo(control: control, position: position)))
        }
    }

    private func parseEllipticalArc() throws {
        guard let groups = parameterGroups(of: 7) else {
            throw SVGPathParserError.invalidParameters("Invalid arc-to parameters \(parameters)")
        }
        for group in groups {
            let radius = CGSize(group[0], group[1]),
                rotation = group[2],
                largeArc = flagOf(value: group[3]),
                sweep = flagOf(value: group[4]),
                position = positionOf(x: group[5], y: group[6])
            guard let largeArc, let sweep else {
                throw SVGPathParserError.invalidParameters("Invalid arc-to flags in \(group)")
            }
            appendCommand(.arcTo(SVGPathCommand.ArcTo(radius: radius, rotation: Angle(degrees: rotation), largeArc: largeArc, sweep: sweep, position: position)))
        }
    }
}
