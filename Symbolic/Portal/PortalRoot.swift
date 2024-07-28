import SwiftUI

// MARK: - PortalWrapper

struct PortalWrapper: View, TracedView, SelectorHolder {
    let portal: PortalData

    class Selector: SelectorBase {
        @Selected({ global.portal.rootFrame }) var rootFrame
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
            .sizeReader { size = $0 }
            .transition(.scale(scale: 0, anchor: anchor).combined(with: .opacity))
            .position(box.center)
            .background {
                if portal.configs.isModal {
                    Color.invisibleSolid
                        .multipleGesture(.init(
                            onPress: { _ in global.portal.deregister(id: portal.id) }
                        ))
                }
            }
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
        let aligns = [align, align.flipped(axis: .horizontal), align.flipped(axis: .vertical)],
            alignAndDistance = aligns.map { (align: $0, distance: reference.alignedBox(at: $0, size: size, gap: gap).center.distance(to: rootFrame.center)) },
            closest = alignAndDistance.min(by: { $0.distance < $1.distance })!.align
        return closest
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
        @Selected(configs: .init(animation: .fast), { global.portal.map.values }) var portals
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
