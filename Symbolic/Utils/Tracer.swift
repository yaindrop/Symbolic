import SwiftUI

let tracerQueue = DispatchQueue(label: "com.example.tracerQueue", qos: .background)

// MARK: - Message

extension Tracer {
    protocol Message {
        var message: String { get }
    }

    struct AnyMessage: Message, ExpressibleByStringLiteral {
        @Getter var message: String

        init<M: Message>(_ instance: M) {
            _message = .init { instance.message }
        }

        init(stringLiteral value: String) {
            _message = .init { value }
        }
    }

    struct StringMessage: Message, ExpressibleByStringLiteral {
        var message: String

        init(stringLiteral value: String) {
            message = value
        }
    }

    struct TaggedMessage: Message {
        let tags: [String]
        let wrapped: AnyMessage

        var message: String { "\(tags.map { "[\($0)]" }.joined(separator: " ")) \(wrapped.message)" }
    }

    protocol CustomStringMessage: Message, CustomStringConvertible {}

    protocol ReflectedStringMessage: CustomStringMessage, ReflectedStringConvertible {}
}

extension Tracer.CustomStringMessage {
    var message: String { description }
}

// MARK: - Node

extension Tracer {
    enum NodeType {
        case intent
        case normal
        case verbose
    }

    enum Node {
        struct Instant {
            let type: NodeType
            let time: ContinuousClock.Instant
            let message: AnyMessage
        }

        struct Range {
            let type: NodeType
            let start: ContinuousClock.Instant
            let end: ContinuousClock.Instant
            let nodes: [Node]
            let message: AnyMessage

            var duration: Duration { start.duration(to: end) }
        }

        case instant(Instant)
        case range(Range)
    }

    // MARK: PendingRange

    struct PendingRange {
        let type: NodeType
        let start: ContinuousClock.Instant
        let message: AnyMessage
        var nodes: [Node] = []
    }

    // MARK: EndRange

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

        fileprivate init() {}

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
            lines.append("\(message.message) (\(duration.readable))")
        }
        for node in nodes {
            switch node {
            case let .instant(i):
                lines.append("\\_(+\(start.duration(to: i.time).readable)) \(i.message.message)")
            case let .range(r):
                lines.append("\\_(+\(start.duration(to: r.start).readable)) \(r.message.message) (\(r.duration.readable))")
                lines += r.buildTreeLines(asRoot: false).map { "\t" + $0 }
            }
        }
        return lines
    }
}

// MARK: - Tracer

class Tracer {
    let setupTime: ContinuousClock.Instant = .now

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

    func instant(type: NodeType = .normal, _ message: @autoclosure () -> String) {
        instant(type: type, AnyMessage(stringLiteral: message()))
    }

    func instant<M: Message>(type: NodeType = .normal, _ message: @autoclosure () -> M) {
        onNode(.instant(.init(type: type, time: .now, message: AnyMessage(message()))))
    }

    func range(type: NodeType = .normal, _ message: @autoclosure () -> String) -> EndRange {
        range(type: type, AnyMessage(stringLiteral: message()))
    }

    func range<M: Message>(type: NodeType = .normal, _ message: @autoclosure () -> M) -> EndRange {
        rangeStack.append(.init(type: type, start: .now, message: AnyMessage(message())))
        return .init(tracer: self)
    }

    func range<Result>(type: NodeType = .normal, _ message: @autoclosure () -> String, _ work: () -> Result) -> Result {
        range(type: type, AnyMessage(stringLiteral: message()), work)
    }

    func range<M: Message, Result>(type: NodeType = .normal, _ message: @autoclosure () -> M, _ work: () -> Result) -> Result {
        let _r = range(type: type, AnyMessage(message())); defer { _r() }
        return work()
    }

    func tagged(_ tag: String, enabled: Bool = true, verbose: Bool = false) -> SubTracer {
        .init(tags: [tag], tracer: self, enabled: enabled, verbose: verbose)
    }

    // MARK: private

    @discardableResult
    private func onEnd(_: EndRange) -> Node.Range? {
        guard let pending = rangeStack.popLast() else { return nil }
        let range = Node.Range(type: pending.type, start: pending.start, end: .now, nodes: pending.nodes, message: pending.message)
        onNode(.range(range))
        return range
    }

    private var nodes: [Node] = []
    private var rangeStack: [PendingRange] = []

    private func onNode(_ node: Node) {
        if var last = rangeStack.popLast() {
            last.nodes.append(node)
            rangeStack.append(last)
            return
        }
        nodes.append(node)
        if case let .range(range) = node {
            tracerQueue.async {
                let startTime = self.setupTime.duration(to: range.start)
                if range.type == .intent {
                    logInfo("[intent] (\(startTime)) \(range.tree)")
                } else {
                    let tree = range.buildTreeLines().enumerated().map { $0 == 0 ? " ... (\(startTime)) \($1)" : "     \($1)" }.joined(separator: "\n")
                    logInfo(tree)
                }
            }
        }
    }
}

// MARK: - SubTracer

extension Tracer {
    struct SubTracer {
        let tags: [String]
        let tracer: Tracer
        var enabled = true
        var verbose = false

        func instant(type: NodeType = .normal, _ message: @autoclosure () -> String) {
            instant(type: type, AnyMessage(stringLiteral: message()))
        }

        func instant<M: Message>(type: NodeType = .normal, _ message: @autoclosure () -> M) {
            guard enabled, verbose || type != .verbose else { return }
            tracer.instant(type: type, TaggedMessage(tags: tags, wrapped: AnyMessage(message())))
        }

        func range(type: NodeType = .normal, _ message: @autoclosure () -> String) -> EndRange {
            range(type: type, AnyMessage(stringLiteral: message()))
        }

        func range<M: Message>(type: NodeType = .normal, _ message: @autoclosure () -> M) -> EndRange {
            guard enabled, verbose || type != .verbose else { return .init() }
            return tracer.range(type: type, TaggedMessage(tags: tags, wrapped: AnyMessage(message())))
        }

        func range<Result>(type: NodeType = .normal, _ message: @autoclosure () -> String, _ work: () -> Result) -> Result {
            range(type: type, AnyMessage(stringLiteral: message()), work)
        }

        func range<M: Message, Result>(type: NodeType = .normal, _ message: @autoclosure () -> M, _ work: () -> Result) -> Result {
            guard enabled, verbose || type != .verbose else { return work() }
            return tracer.range(type: type, TaggedMessage(tags: tags, wrapped: AnyMessage(message())), work)
        }

        func tagged(_ tag: String, enabled: Bool = true, verbose: Bool = false) -> SubTracer {
            .init(tags: tags + [tag], tracer: tracer, enabled: enabled, verbose: verbose)
        }
    }
}

// MARK: - TracedView

protocol TracedView: View {}

extension TracedView {
    func trace<Content: View>(_ message: @autoclosure () -> String? = nil, @ViewBuilder _ work: () -> Content) -> Content {
        trace(Tracer.AnyMessage(stringLiteral: message() ?? "body"), work)
    }

    func trace<M: Tracer.Message, Content: View>(_ message: @autoclosure () -> M, @ViewBuilder _ work: () -> Content) -> Content {
        tracer.range(type: .normal, Tracer.TaggedMessage(tags: [String(describing: type(of: self))], wrapped: Tracer.AnyMessage(message())), work)
    }
}

let tracer = Tracer()
