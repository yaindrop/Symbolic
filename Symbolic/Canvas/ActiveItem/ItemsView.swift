import SwiftUI

// MARK: - ItemsView

struct ItemsView: View, TracedView, SelectorHolder {
    class Selector: SelectorBase {
        override var configs: SelectorConfigs { .init(syncNotify: true) }
        @Selected({ global.viewport.sizedInfo }) var sizedViewport
        @Selected({ global.item.allPaths }) var allPaths
        @Selected({ global.activeItem.focusedItemId }) var focusedItemId
    }

    @SelectorWrapper var selector

    var body: some View { trace {
        setupSelector {
            content
        }
    } }
}

// MARK: private

private extension ItemsView {
    @ViewBuilder var content: some View {
        ForEach(selector.allPaths.filter { $0.id != selector.focusedItemId }) { p in
            SUPath { path in p.append(to: &path) }
                .stroke(Color(UIColor.label), style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
        }
        .modifier(ViewportEffect(keyPath: \.worldToView, sizedViewport: selector.sizedViewport))
//        .blur(radius: 1)
    }
}

struct ViewportEffect: GeometryEffect {
    let keyPath: KeyPath<ViewportInfo, CGAffineTransform>
    var sizedViewport: SizedViewportInfo

    var animatableData: SizedViewportInfo.AnimatableData {
        get { sizedViewport.animatableData }
        set { sizedViewport.animatableData = newValue }
    }

    func effectValue(size _: CGSize) -> ProjectionTransform {
        .init(sizedViewport.info[keyPath: keyPath])
    }
}
