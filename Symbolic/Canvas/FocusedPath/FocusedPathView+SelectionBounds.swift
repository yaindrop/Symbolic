import SwiftUI

// MARK: - SelectionBounds

extension FocusedPathView {
    struct SelectionBounds: View, TracedView, SelectorHolder {
        class Selector: SelectorBase {
            @Selected(configs: .init(syncNotify: true), { global.viewport.sizedInfo }) var viewport
            @Selected(configs: .init(syncNotify: true), { global.activeItem.focusedPath }) var path
            @Selected({ global.focusedPath.activeNodeIndexPairs }) var nodeIndexPairs
            @Selected({ global.activeSymbol.symbolToWorld }) var symbolToWorld
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
        AnimatableReader(selector.viewport) {
            let transform = selector.symbolToWorld.concatenating($0.worldToView)
            shape(transform: transform)
        }
    }

    var strokedWidth: Scalar { 24 }
    var lineWidth: Scalar { 2 }
    var dashSize: Scalar { 8 }
    var color: Color { .blue.opacity(0.5) }

    @ViewBuilder func shape(transform: CGAffineTransform) -> some View {
        SUPath { p in
            for pair in selector.nodeIndexPairs {
                if pair.first == pair.second {
                    appendNode(to: &p, at: pair.first, transform: transform)
                } else {
                    appendSubpath(to: &p, from: pair.first, to: pair.second, transform: transform)
                }
            }
        }
        .stroke(color, style: .init(lineWidth: lineWidth, dash: [dashSize], dashPhase: dashPhase))
        .animatedValue($dashPhase, from: 0, to: dashSize * 2, .linear(duration: 0.4).repeatForever(autoreverses: false))
    }

    func appendSubpath(to p: inout SUPath, from: Int, to: Int, transform: CGAffineTransform) {
        guard let path = selector.path,
              let subpath = path.subpath(from: from, to: to)?.applying(transform) else { return }
        let stroked = SUPath { p in subpath.append(to: &p) }
            .strokedPath(.init(lineWidth: strokedWidth, lineCap: .round, lineJoin: .round))
        p.addPath(stroked)
    }

    func appendNode(to p: inout SUPath, at i: Int, transform: CGAffineTransform) {
        guard let path = selector.path,
              let node = path.node(at: i)?.applying(transform) else { return }
        p.addEllipse(in: .init(center: node.position, size: .init(squared: strokedWidth)))
    }
}
