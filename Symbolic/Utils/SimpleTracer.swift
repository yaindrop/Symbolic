import Foundation
import SwiftUI

extension Tracer {
    // MARK: - Node

    enum NodeType {
        case intent
        case normal
    }

    enum Node {
        struct Instant {
            let type: NodeType
            let time: ContinuousClock.Instant
            let message: String
        }

        struct Range {
            let type: NodeType
            let start: ContinuousClock.Instant
            let end: ContinuousClock.Instant
            let nodes: [Node]
            let message: String

            var duration: Duration { start.duration(to: end) }
        }

        case instant(Instant)
        case range(Range)
    }

    // MARK: - PendingRange

    struct PendingRange {
        let type: NodeType
        let start: ContinuousClock.Instant
        let message: String
        var nodes: [Node] = []
    }

    // MARK: - EndRange

    class EndRange {
        @discardableResult
        func callAsFunction() -> Node.Range? {
            ended = true
            return tracer?.onEnd(self)
        }

        deinit {
            if !ended {
                logWarning("Range not ended manually.")
                tracer?.onEnd(self)
            }
        }

        fileprivate init(tracer: Tracer) {
            self.tracer = tracer
        }

        private weak var tracer: Tracer?
        private var ended: Bool = false
    }
}

// MARK: - CustomStringConvertible

extension Tracer.Node.Instant: CustomStringConvertible {
    var description: String {
        "Instant(\(message))"
    }
}

extension Tracer.Node.Range: CustomStringConvertible {
    var description: String {
        "Range(\(message), \(duration.readable))"
    }
}

extension Tracer.Node: CustomStringConvertible {
    var description: String {
        switch self {
        case let .instant(i): i.description
        case let .range(r): r.description
        }
    }
}

// MARK: - tree

extension Tracer.Node.Range {
    var tree: String { buildTreeLines().joined(separator: "\n") }

    func buildTreeLines(asRoot: Bool = true) -> [String] {
        var lines: [String] = []
        if asRoot {
            lines.append("\(message) (\(duration.readable))")
        }
        for node in nodes {
            switch node {
            case let .instant(i):
                lines.append("\\_(+\(start.duration(to: i.time).readable)) \(i.message)")
            case let .range(r):
                lines.append("\\_(+\(start.duration(to: r.start).readable)) \(r.message) (\(r.duration.readable))")
                lines += r.buildTreeLines(asRoot: false).map { "\t" + $0 }
            }
        }
        return lines
    }
}

// MARK: - Tracer

class Tracer {
    var enabled = true

    func start() {
        nodes.removeAll()
        rangeStack.removeAll()
    }

    func end() -> [Node] {
        guard enabled else { return [] }
        let recorded = nodes
        nodes.removeAll()
        rangeStack.removeAll()
        return recorded
    }

    func instant(_ message: String) {
        guard enabled else { return }
        onNode(.instant(.init(type: .normal, time: .now, message: message)))
    }

    func range(_ message: String, type: NodeType = .normal) -> EndRange {
        guard enabled else { return .init(tracer: self) }
        rangeStack.append(.init(type: type, start: .now, message: message))
        return .init(tracer: self)
    }

    func range<Result>(_ message: String, type: Tracer.NodeType = .normal, _ work: () -> Result) -> Result {
        guard enabled else { return work() }
        let _r = range(message, type: type); defer { _r() }
        return work()
    }

    func tagged(_ tag: String, enabled: Bool = true) -> SubTracer {
        .init(tags: [tag], tracer: self, enabled: enabled)
    }

    // MARK: private

    @discardableResult
    private func onEnd(_: EndRange) -> Node.Range? {
        guard enabled else { return nil }
        guard let pending = rangeStack.popLast() else { return nil }
        let range = Node.Range(type: pending.type, start: pending.start, end: .now, nodes: pending.nodes, message: pending.message)
        onNode(.range(range))
        return range
    }

    private var nodes: [Node] = []
    private var rangeStack: [PendingRange] = []

    private func onNode(_ node: Node) {
        if rangeStack.isEmpty {
            nodes.append(node)
            if case let .range(r) = node {
                if r.type == .intent {
                    logInfo("[intent] \(r.tree)")
                } else {
                    let tree = r.buildTreeLines().enumerated().map { $0 == 0 ? " ... \($1)" : "     \($1)" }.joined(separator: "\n")
                    logInfo(tree)
                }
            }
        } else {
            rangeStack[rangeStack.count - 1].nodes.append(node)
        }
    }
}

struct SubTracer {
    let tags: [String]
    let tracer: Tracer
    var enabled = true

    var prefix: String { tags.map { "[\($0)]" }.joined(separator: " ") }

    func instant(_ message: String) {
        tracer.instant("\(prefix) \(message)")
    }

    func range(_ message: String, type: Tracer.NodeType = .normal) -> Tracer.EndRange {
        tracer.range("\(prefix) \(message)", type: type)
    }

    func range<Result>(_ message: String, type: Tracer.NodeType = .normal, _ work: () -> Result) -> Result {
        tracer.range("\(prefix) \(message)", type: type, work)
    }

    func tagged(_ tag: String, enabled: Bool = true) -> SubTracer {
        .init(tags: tags + [tag], tracer: tracer, enabled: enabled)
    }
}

let tracer = Tracer()
