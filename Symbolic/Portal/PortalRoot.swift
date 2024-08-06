import SwiftUI

// MARK: - PortalWrapper

struct PortalWrapper: View, TracedView, SelectorHolder {
    let portal: PortalData

    class Selector: SelectorBase {
        @Selected({ global.portal.rootFrame }) var rootFrame
        @Selected({ global.root.rootPanLocation }) var rootPanLocation
    }

    @SelectorWrapper var selector

    @State private var size: CGSize = .zero

    var body: some View { trace {
        setupSelector {
            content
        }
    } }
}

// MARK: private

extension PortalWrapper {
    var content: some View {
        portal.view
            .transaction { $0.animation = nil }
            .sizeReader { size = $0 }
            .transition(.scale(scale: 0, anchor: anchor).combined(with: .opacity))
            .if(portal.configs.isModal) {
                $0.overlay {
                    GeometryReader { ctx in
                        let frame = ctx.frame(in: .global),
                            dismissed = selector.rootPanLocation.map { !frame.contains($0) } ?? false
                        Color.clear
                            .onChange(of: dismissed) {
                                if dismissed {
                                    global.portal.deregister(id: portal.id)
                                }
                            }
                    }
                }
            }
            .position(box.center)
            .environment(\.portalId, portal.id)
    }

    var align: PlaneOuterAlign {
        let rootFrame = selector.rootFrame,
            align = portal.configs.align,
            gap = portal.configs.gap,
            reference = portal.reference,
            box = reference.alignedBox(at: align, size: size, gap: gap)
        if rootFrame.contains(box) {
            return align
        }
        let flippedAligns = [align.flipped(axis: .horizontal), align.flipped(axis: .vertical), align.flipped(axis: .horizontal).flipped(axis: .vertical)],
            containedAlign = flippedAligns.first { rootFrame.contains(reference.alignedBox(at: $0, size: size, gap: gap)) }
        return containedAlign ?? align
    }

    var box: CGRect {
        let rootFrame = selector.rootFrame,
            gap = portal.configs.gap,
            reference = portal.reference,
            box = reference.alignedBox(at: align, size: size, gap: gap)
        return box.clamped(by: rootFrame)
    }

    var anchor: UnitPoint {
        let rootFrame = selector.rootFrame,
            point = portal.reference.alignedPoint(at: align.innerAlign)
        return .init(x: point.x / rootFrame.width, y: point.y / rootFrame.height)
    }
}

// MARK: - PortalRoot

struct PortalRoot: View, TracedView, SelectorHolder {
    class Selector: SelectorBase {
        @Selected(configs: .init(syncNotify: true, animation: .fast), { global.portal.map.values }) var portals
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
        .geometryReader { global.portal.setRootFrame($0.frame(in: .global)) }
    }
}
