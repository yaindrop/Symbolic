import SwiftUI

// MARK: - SelectionBounds

extension FocusedPathView {
    struct SelectionBounds: View, TracedView, SelectorHolder {
        class Selector: SelectorBase {
            override var syncUpdate: Bool { true }
            @Selected({ global.activeItem.focusedPath?.continuousNodeIndices(nodeIds: global.focusedPath.activeNodeIds) }) var nodeIndices
        }

        @SelectorWrapper var selector

        var body: some View { trace {
            setupSelector {
                content
            }
        } }
    }
}

// MARK: private

private extension FocusedPathView.SelectionBounds {
    @ViewBuilder var content: some View {
        if let nodeIndices = selector.nodeIndices {
            ForEach(nodeIndices, id: \.from) {
                if $0.from == $0.to {
                    NodeBounds(index: $0.from)
                } else {
                    SubpathBounds(from: $0.from, to: $0.to)
                }
            }
        }
    }
}

// MARK: - SubpathBounds

private struct SubpathBounds: View, TracedView, EquatableBy, ComputedSelectorHolder {
    let from: Int
    let to: Int

    var equatableBy: some Equatable { from; to }

    struct SelectorProps: Equatable { let from: Int, to: Int }
    class Selector: SelectorBase {
        override var syncUpdate: Bool { true }
        @Selected({ global.activeItem.focusedPath?.subpath(from: $0.from, to: $0.to) }) var subpath
        @Selected({ global.viewport.info }) var viewport
    }

    @SelectorWrapper var selector

    var body: some View { trace {
        setupSelector(.init(from: from, to: to)) {
            content
        }
    } }
}

// MARK: private

private extension SubpathBounds {
    var color: Color { .blue.opacity(0.5) }
    var strokedWidth: Scalar { 24 }
    var lineWidth: Scalar { 2 }
    var dashSize: Scalar { 8 }

    @ViewBuilder var content: some View {
        if let subpath = selector.subpath {
            let width = (strokedWidth * Vector2.unitX).applying(selector.viewport.viewToWorld).dx
            AnimatedValue(from: 0, to: dashSize * 2, .linear(duration: 0.4).repeatForever(autoreverses: false)) { dashPhase in
                SUPath { subpath.append(to: &$0) }
                    .strokedPath(.init(lineWidth: width, lineCap: .round, lineJoin: .round))
                    .transform(selector.viewport.worldToView)
                    .stroke(color, style: .init(lineWidth: lineWidth, dash: [dashSize], dashPhase: dashPhase))
            }
        }
    }
}

// MARK: - NodeBounds

private struct NodeBounds: View, TracedView, EquatableBy, ComputedSelectorHolder {
    let index: Int

    var equatableBy: some Equatable { index }

    struct SelectorProps: Equatable { let index: Int }
    class Selector: SelectorBase {
        override var syncUpdate: Bool { true }
        @Selected({ global.activeItem.focusedPath?.node(at: $0.index) }) var node
        @Selected({ global.viewport.info }) var viewport
    }

    @SelectorWrapper var selector

    var body: some View { trace {
        setupSelector(.init(index: index)) {
            content
        }
    } }
}

// MARK: private

private extension NodeBounds {
    var color: Color { .blue.opacity(0.5) }
    var strokedWidth: Scalar { 24 }
    var lineWidth: Scalar { 2 }
    var dashSize: Scalar { 8 }

    @ViewBuilder var content: some View {
        if let node = selector.node {
            AnimatedValue(from: 0, to: dashSize * 2, .linear(duration: 0.4).repeatForever(autoreverses: false)) { dashPhase in
                Circle()
                    .stroke(color, style: .init(lineWidth: lineWidth, dash: [dashSize], dashPhase: dashPhase))
                    .framePosition(rect: .init(center: node.position.applying(selector.viewport.worldToView), size: .init(squared: strokedWidth)))
            }
        }
    }
}
