import SwiftUI

struct PortalWrapper: View, TracedView {
    let portal: PortalData

    @State private var size: CGSize = .zero

    var body: some View { trace {
        let box = portal.reference.alignedBox(at: portal.align, size: size)
        portal.view
            .sizeReader { size = $0 }
            .position(box.center)
            .background {
                if portal.isModal {
                    Color.invisibleSolid
                        .multipleGesture(.init(
                            onPress: { _ in global.portal.deregister(id: portal.id) }
                        ))
                }
            }
            .environment(\.portalId, portal.id)
    } }
}

// MARK: - PortalRoot

struct PortalRoot: View, TracedView, SelectorHolder {
    class Selector: SelectorBase {
        @Selected({ global.portal.portalMap.values }) var portals
    }

    @SelectorWrapper var selector

    var body: some View { trace {
        setupSelector {
            content
        }
    } }
}

// MARK: private

private extension PortalRoot {
    var content: some View {
        ZStack {
            ForEach(selector.portals) { PortalWrapper(portal: $0) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
