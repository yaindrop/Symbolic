import SwiftUI

// MARK: - SelectionBounds

extension FocusedPathView {
    struct SelectionBounds: View, TracedView, SelectorHolder {
        class Selector: SelectorBase {
            override var configs: SelectorConfigs { .init(syncNotify: true) }
            @Selected({ global.focusedPath.activeNodeIndexPairs }) var nodeIndexPairs
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
        ForEach(selector.nodeIndexPairs, id: \.first) {
            if $0.first == $0.second {
                NodeBounds(index: $0.first)
            } else {
                SubpathBounds(from: $0.first, to: $0.second)
            }
        }
    }
}

// MARK: - SubpathBounds

private struct SubpathBounds: View, TracedView, ComputedSelectorHolder {
    let from: Int, to: Int

    struct SelectorProps: Equatable { let from: Int, to: Int }
    class Selector: SelectorBase {
        override var configs: SelectorConfigs { .init(syncNotify: true) }
        @Selected({ global.viewport.sizedInfo }) var viewport
        @Selected({ global.focusedPath.subpath(from: $0.from, to: $0.to) }) var subpath
    }

    @SelectorWrapper var selector

    @State private var dashPhase: Scalar = 0

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
            AnimatableReader(selector.viewport) {
                let width = (strokedWidth * Vector2.unitX).applying($0.viewToWorld).dx
                SUPath { subpath.append(to: &$0) }
                    .strokedPath(.init(lineWidth: width, lineCap: .round, lineJoin: .round))
                    .transform($0.worldToView)
                    .stroke(color, style: .init(lineWidth: lineWidth, dash: [dashSize], dashPhase: dashPhase))
                    .animatedValue($dashPhase, from: 0, to: dashSize * 2, .linear(duration: 0.4).repeatForever(autoreverses: false))
            }
        }
    }
}

// MARK: - NodeBounds

private struct NodeBounds: View, TracedView, ComputedSelectorHolder {
    let index: Int

    struct SelectorProps: Equatable { let index: Int }
    class Selector: SelectorBase {
        override var configs: SelectorConfigs { .init(syncNotify: true) }
        @Selected({ global.viewport.sizedInfo }) var viewport
        @Selected({ global.activeItem.focusedPath?.node(at: $0.index) }) var node
    }

    @SelectorWrapper var selector

    @State private var dashPhase: Scalar = 0

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
            AnimatableReader(selector.viewport) {
                Circle()
                    .stroke(color, style: .init(lineWidth: lineWidth, dash: [dashSize], dashPhase: dashPhase))
                    .framePosition(rect: .init(center: node.position.applying($0.worldToView), size: .init(squared: strokedWidth)))
                    .animatedValue($dashPhase, from: 0, to: dashSize * 2, .linear(duration: 0.4).repeatForever(autoreverses: false))
            }
        }
    }
}
