import SwiftUI

// MARK: - SelectionBounds

extension FocusedPathView {
    struct SelectionBounds: View, TracedView, SelectorHolder {
        @Environment(\.transformToView) var transformToView

        class Selector: SelectorBase {
            @Selected(configs: .init(syncNotify: true), { global.activeItem.focusedPath }) var path
            @Selected({ global.focusedPath.activeNodeIndexPairs }) var nodeIndexPairs
        }

        @SelectorWrapper var selector

        @State private var dashPhase: Scalar = 0

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
        shape
    }

    var strokedWidth: Scalar { 24 }
    var lineWidth: Scalar { 2 }
    var dashSize: Scalar { 8 }
    var color: Color { .blue.opacity(0.5) }

    @ViewBuilder var shape: some View {
        SUPath { p in
            for pair in selector.nodeIndexPairs {
                if pair.first == pair.second {
                    appendNode(to: &p, at: pair.first)
                } else {
                    appendSubpath(to: &p, from: pair.first, to: pair.second)
                }
            }
        }
        .stroke(color, style: .init(lineWidth: lineWidth, dash: [dashSize], dashPhase: dashPhase))
        .animatedValue($dashPhase, from: 0, to: dashSize * 2, .linear(duration: 0.4).repeatForever(autoreverses: false))
    }

    func appendSubpath(to p: inout SUPath, from: Int, to: Int) {
        guard let path = selector.path,
              let subpath = path.subpath(from: from, to: to)?.applying(transformToView) else { return }
        let stroked = SUPath { p in subpath.append(to: &p) }
            .strokedPath(.init(lineWidth: strokedWidth, lineCap: .round, lineJoin: .round))
        p.addPath(stroked)
    }

    func appendNode(to p: inout SUPath, at i: Int) {
        guard let path = selector.path,
              let node = path.node(at: i)?.applying(transformToView) else { return }
        p.addEllipse(in: .init(center: node.position, size: .init(squared: strokedWidth)))
    }
}
