//
//  SVGPath.swift
//  Symbolic
//
//  Created by Yaindrop on 2024/4/15.
//

import Foundation
import SwiftUI

// MARK: SVGPathCommand

protocol SVGPathPosition {
    var position: CGPoint { get }
}

struct SVGPathCommandLineTo: CustomStringConvertible, SVGPathPosition {
    var position: CGPoint
    public var description: String { return "L \(position.x) \(position.y)" }
}

struct SVGPathCommandArcTo: CustomStringConvertible, SVGPathPosition {
    var radius: CGSize
    var rotation: Angle
    var largeArc: Bool
    var sweep: Bool
    var position: CGPoint
    public var description: String { return "A \(radius.width) \(radius.height) \(rotation) \(largeArc ? 1 : 0) \(sweep ? 1 : 0) \(position.x) \(position.y)" }
}

struct SVGPathCommandBezierTo: CustomStringConvertible, SVGPathPosition {
    var control0: CGPoint
    var control1: CGPoint
    var position: CGPoint

    func toQuadratic(current: CGPoint) -> SVGPathCommandQuadraticBezierTo? {
        let quadraticControl0 = current + current.deltaVector(to: control0) * 3 / 2
        let quadraticControl1 = position + position.deltaVector(to: control1) * 3 / 2
        guard quadraticControl0 == quadraticControl1 else { return nil }
        return SVGPathCommandQuadraticBezierTo(control: quadraticControl0, position: position)
    }

    public var description: String { return "C \(control0.x) \(control0.y) \(control1.x) \(control1.y) \(position.x) \(position.y)" }
}

struct SVGPathCommandQuadraticBezierTo: CustomStringConvertible, SVGPathPosition {
    var control: CGPoint
    var position: CGPoint

    func toCubic(current: CGPoint) -> SVGPathCommandBezierTo {
        let control0 = current + (current.deltaVector(to: control)) * 2 / 3
        let control1 = position + (position.deltaVector(to: control)) * 2 / 3
        return SVGPathCommandBezierTo(control0: control0, control1: control1, position: position)
    }

    public var description: String { return "Q \(control.x) \(control.y) \(position.x) \(position.y)" }
}

enum SVGPathCommand: SVGPathPosition {
    case LineTo(SVGPathCommandLineTo)
    case ArcTo(SVGPathCommandArcTo)
    case BezierTo(SVGPathCommandBezierTo)
    case QuadraticBezierTo(SVGPathCommandQuadraticBezierTo)

    var position: CGPoint {
        switch self {
        case let .ArcTo(c):
            return c.position
        case let .BezierTo(c):
            return c.position
        case let .LineTo(c):
            return c.position
        case let .QuadraticBezierTo(c):
            return c.position
        }
    }
}

struct SVGPath {
    var initial: CGPoint = CGPoint.zero
    var commands: Array<SVGPathCommand> = []
    var isClosed: Bool = false

    var isEmpty: Bool { commands.isEmpty }

    var last: CGPoint {
        guard let last = commands.last else { return CGPoint.zero }
        return last.position
    }
}

// MARK: SVGPathParser

enum SVGPathParserError: Error {
    case invalidCommand(String)
    case invalidParameters(String)
}

// reference https://www.w3.org/TR/SVG11/paths.html
class SVGPathParser {
    var paths: Array<SVGPath> = []

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
    private var parameters: Array<CGFloat> = []

    // MARK: scan

    private func scan() throws {
        command = try scanCommand()
        parameters = try scanParameters()
        switch command.uppercased() {
        case "M":
            try parseMoveTo()
        case "Z":
            try parseClosePath()
        case "L":
            try parseLineTo()
        case "H":
            try parseHorizontalLineTo()
        case "V":
            try parseVerticalLineTo()
        case "C":
            try parseCurveTo()
        case "S":
            try parseSmoothCurveTo()
        case "Q":
            try parseQuadraticBezierCurveTo()
        case "T":
            try parseSmoothQuadraticBezierCurveTo()
        case "A":
            try parseEllipticalArc()
        default:
            break
        }
    }

    private func scanCommand() throws -> Character {
        guard let command = scanner.scanCharacter(), SVGPathParser.commandSet.contains(command) else {
            throw SVGPathParserError.invalidCommand("Expect command at \(scanner.currentIndex)")
        }
        return command
    }

    private func scanParameters() throws -> Array<CGFloat> {
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

    private func appendPath(withClosed isClosed: Bool, moveTo: CGPoint = CGPoint.zero) {
        if !path.isEmpty {
            paths.append(path)
        }
        path = SVGPath(initial: moveTo)
    }

    // MARK: parameter getter

    private func parameterGroups(of n: Int) -> Array<Array<CGFloat>>? {
        guard parameters.count % n == 0 else { return nil }
        var groups: Array<Array<CGFloat>> = []
        for i in stride(from: 0, to: parameters.count, by: n) {
            groups.append(Array(parameters[i ..< i + n]))
        }
        return groups
    }

    private func positionOf(x: CGFloat, y: CGFloat) -> CGPoint {
        if isRelative {
            return path.last + CGVector(dx: x, dy: y)
        } else {
            return CGPoint(x: x, y: y)
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
            appendCommand(.LineTo(SVGPathCommandLineTo(position: lineToPosition)))
        }
    }

    private func parseClosePath() throws {
        guard parameters.isEmpty else {
            throw SVGPathParserError.invalidParameters("Cloth path cannot have parameters \(parameters)")
        }
        appendPath(withClosed: true)
    }

    private func parseLineTo() throws {
        guard let groups = parameterGroups(of: 2) else {
            throw SVGPathParserError.invalidParameters("Invalid line-to parameters \(parameters)")
        }
        for group in groups {
            let position = positionOf(x: group[0], y: group[1])
            appendCommand(.LineTo(SVGPathCommandLineTo(position: position)))
        }
    }

    private func parseHorizontalLineTo() throws {
        guard !parameters.isEmpty else {
            throw SVGPathParserError.invalidParameters("Invalid horizontal line-to parameters \(parameters)")
        }
        for x in parameters {
            let position = positionOf(x: x, y: 0)
            appendCommand(.LineTo(SVGPathCommandLineTo(position: position)))
        }
    }

    private func parseVerticalLineTo() throws {
        guard !parameters.isEmpty else {
            throw SVGPathParserError.invalidParameters("Invalid vertical line-to parameters \(parameters)")
        }
        for y in parameters {
            let position = positionOf(x: 0, y: y)
            appendCommand(.LineTo(SVGPathCommandLineTo(position: position)))
        }
    }

    private func parseCurveTo() throws {
        guard let groups = parameterGroups(of: 6) else {
            throw SVGPathParserError.invalidParameters("Invalid curve-to parameters \(parameters)")
        }
        for group in groups {
            let control0 = positionOf(x: group[0], y: group[1])
            let control1 = positionOf(x: group[2], y: group[3])
            let position = positionOf(x: group[4], y: group[5])
            appendCommand(.BezierTo(SVGPathCommandBezierTo(control0: control0, control1: control1, position: position)))
        }
    }

    private func parseSmoothCurveTo() throws {
        guard let groups = parameterGroups(of: 4) else {
            throw SVGPathParserError.invalidParameters("Invalid smooth curve-to parameters \(parameters)")
        }
        var control0 = path.last
        if let lastCommand = path.commands.last, case let .BezierTo(lastBezier) = lastCommand {
            control0 = lastBezier.position + lastBezier.control1.deltaVector(to: lastBezier.position)
        }
        for group in groups {
            let control1 = positionOf(x: group[0], y: group[1])
            let position = positionOf(x: group[2], y: group[3])
            appendCommand(.BezierTo(SVGPathCommandBezierTo(control0: control0, control1: control1, position: position)))
        }
    }

    private func parseQuadraticBezierCurveTo() throws {
        guard let groups = parameterGroups(of: 4) else {
            throw SVGPathParserError.invalidParameters("Invalid quadratic bezier curve-to parameters \(parameters)")
        }
        for group in groups {
            let control = positionOf(x: group[0], y: group[1])
            let position = positionOf(x: group[2], y: group[3])
            appendCommand(.QuadraticBezierTo(SVGPathCommandQuadraticBezierTo(control: control, position: position)))
        }
    }

    private func parseSmoothQuadraticBezierCurveTo() throws {
        guard let groups = parameterGroups(of: 2) else {
            throw SVGPathParserError.invalidParameters("Invalid smooth quadratic bezier curve-to parameters \(parameters)")
        }
        var control = path.last
        if let lastCommand = path.commands.last, case let .QuadraticBezierTo(lastQuadraticBezier) = lastCommand {
            control = lastQuadraticBezier.position + lastQuadraticBezier.control.deltaVector(to: lastQuadraticBezier.position)
        }
        for group in groups {
            let position = positionOf(x: group[0], y: group[1])
            appendCommand(.QuadraticBezierTo(SVGPathCommandQuadraticBezierTo(control: control, position: position)))
        }
    }

    private func parseEllipticalArc() throws {
        guard let groups = parameterGroups(of: 7) else {
            throw SVGPathParserError.invalidParameters("Invalid arc-to parameters \(parameters)")
        }
        for group in groups {
            let radius = CGSize(width: group[0], height: group[1])
            let rotation = group[2]
            guard let largeArc = flagOf(value: group[3]), let sweep = flagOf(value: group[4]) else {
                throw SVGPathParserError.invalidParameters("Invalid arc-to flags in \(group)")
            }
            let position = positionOf(x: group[5], y: group[6])
            appendCommand(.ArcTo(SVGPathCommandArcTo(radius: radius, rotation: Angle(degrees: rotation), largeArc: largeArc, sweep: sweep, position: position)))
        }
    }
}
