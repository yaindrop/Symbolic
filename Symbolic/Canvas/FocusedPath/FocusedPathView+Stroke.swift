import SwiftUI

// MARK: - Stroke

extension FocusedPathView {
    struct Stroke: View, TracedView, EquatableBy, ComputedSelectorHolder {
        let pathId: UUID

        var equatableBy: some Equatable { pathId }

        struct SelectorProps: Equatable { let pathId: UUID }
        class Selector: SelectorBase {
            override var configs: SelectorConfigs { .init(syncNotify: true) }
            @Selected({ global.viewport.sizedInfo }) var viewport
            @Selected({ global.path.get(id: $0.pathId) }) var path
        }

        @SelectorWrapper var selector

        var body: some View { trace {
            setupSelector(.init(pathId: pathId)) {
                content
            }
        } }
    }
}

// MARK: private

private extension FocusedPathView.Stroke {
    @ViewBuilder var content: some View {
        if let path = selector.path {
            AnimatableReader(selector.viewport) {
                SUPath { path.append(to: &$0) }
                    .stroke(Color(UIColor.label), style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
                    .allowsHitTesting(false)
                    .transformEffect($0.worldToView)
                    .id(path.id)
            }
        }
    }
}
