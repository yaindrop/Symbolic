import Foundation

extension SimpleTracer {
    enum Node {
        struct Instant {
            let time: Date
            let message: String
        }

        struct Range {
            let start: Date
            let end: Date
            let nodes: [Node]
            let message: String

            var interval: TimeInterval { end.timeIntervalSince(start) }
        }

        case instant(Instant)
        case range(Range)
    }

    struct PendingRange {
        let start: Date
        let message: String
        var nodes: [Node] = []
    }

    class EndRange {
        @discardableResult
        func callAsFunction() -> Node.Range? {
            ended = true
            return tracer?.onEnd(self)
        }

        deinit {
            if !ended {
                logWarning("not ended!")
                tracer?.onEnd(self)
            }
        }

        fileprivate init(tracer: SimpleTracer) {
            self.tracer = tracer
        }

        private weak var tracer: SimpleTracer?
        private var ended: Bool = false
    }
}

extension SimpleTracer.Node.Instant: CustomStringConvertible {
    var description: String {
        "Instant(\(message))"
    }
}

extension SimpleTracer.Node.Range: CustomStringConvertible {
    var description: String {
        "Range(\(message), \(interval))"
    }

    var tree: String { buildTreeLines().joined(separator: "\n") }

    private func buildTreeLines(asRoot: Bool = true) -> [String] {
        var lines: [String] = []
        if asRoot {
            lines.append("\(message) lasting \(interval.readableTime) at \(start.timeIntervalSince1970)")
        }
        for node in nodes {
            switch node {
            case let .instant(i):
                lines.append("\\_(+\(i.time.timeIntervalSince(start).readableTime)) \(i.message)")
            case let .range(r):
                lines.append("\\_(+\(r.start.timeIntervalSince(start).readableTime)) \(r.message) lasting \(r.interval.readableTime)")
                lines += r.buildTreeLines(asRoot: false).map { "\t" + $0 }
            }
        }
        return lines
    }
}

extension SimpleTracer.Node: CustomStringConvertible {
    var description: String {
        switch self {
        case let .instant(i): i.description
        case let .range(r): r.description
        }
    }
}

class SimpleTracer {
    func start() {
        nodes.removeAll()
        rangeStack.removeAll()
    }

    func end() -> [Node] {
        let recorded = nodes
        nodes.removeAll()
        rangeStack.removeAll()
        return recorded
    }

    func instant(_ message: String) {
        onNode(.instant(.init(time: .now, message: message)))
    }

    func range(_ message: String) -> EndRange {
        rangeStack.append(.init(start: .now, message: message))
        return .init(tracer: self)
    }

    @discardableResult
    fileprivate func onEnd(_ endRange: EndRange) -> Node.Range? {
        guard let pending = rangeStack.popLast() else { return nil }
        let range = Node.Range(start: pending.start, end: .now, nodes: pending.nodes, message: pending.message)
        onNode(.range(range))
        return range
    }

    private var nodes: [Node] = []
    private var rangeStack: [PendingRange] = []

    private func onNode(_ node: Node) {
        if rangeStack.isEmpty {
            nodes.append(node)
        } else {
            rangeStack[rangeStack.count - 1].nodes.append(node)
        }
    }
}

let tracer = SimpleTracer()
