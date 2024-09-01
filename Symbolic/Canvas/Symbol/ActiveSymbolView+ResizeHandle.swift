import SwiftUI

// MARK: - global actions

private extension GlobalStores {
    func onDrag(symbolId: UUID, align: PlaneInnerAlign, _ v: DragGesture.Value, pending: Bool = false) {
        let offset = v.offset.applying(viewport.viewToWorld)
        documentUpdater.update(symbol: .resize(.init(symbolId: symbolId, align: align, offset: offset)), pending: pending)
    }

    func gesture(symbolId: UUID, align: PlaneInnerAlign) -> MultipleGesture {
        .init(
            onPress: { _ in
                canvasAction.start(continuous: .resizeSymbol)
            },
            onPressEnd: { _, cancelled in
                canvasAction.end(continuous: .resizeSymbol)
                if cancelled { documentUpdater.cancel() }
            },

            onDrag: { onDrag(symbolId: symbolId, align: align, $0, pending: true) },
            onDragEnd: { onDrag(symbolId: symbolId, align: align, $0) }
        )
    }
}

// MARK: - ResizeHandle

extension ActiveSymbolView {
    struct ResizeHandle: View, TracedView, EquatableBy, ComputedSelectorHolder {
        @Environment(\.transformToView) var transformToView

        let symbolId: UUID

        var equatableBy: some Equatable { symbolId }

        struct SelectorProps: Equatable { let symbolId: UUID }
        class Selector: SelectorBase {
            override var configs: SelectorConfigs { .syncNotify }
            @Selected({ global.symbol.get(id: $0.symbolId)?.boundingRect }) var bounds
        }

        @SelectorWrapper var selector

        var body: some View { trace {
            setupSelector(.init(symbolId: symbolId)) {
                content
            }
        } }
    }
}

// MARK: private

extension ActiveSymbolView.ResizeHandle {
    @ViewBuilder var content: some View {
        let aligns: [PlaneInnerAlign] = [.topLeading, .topTrailing, .bottomLeading, .bottomTrailing]
        if let bounds = selector.bounds {
            let bounds = bounds.applying(transformToView)
            ForEach(aligns) {
                shape(bounds: bounds, align: $0)
                touchable(bounds: bounds, align: $0)
            }
        }
    }

    var gap: Scalar { 6 }

    var size: Scalar { 12 }

    var touchableSize: Scalar { 40 }

    func visible(bounds: CGRect) -> Bool {
        bounds.width > size * 2 && bounds.height > size * 2
    }

    @ViewBuilder func shape(bounds: CGRect, align: PlaneInnerAlign) -> some View {
        SUPath {
            guard visible(bounds: bounds) else { return }
            let bounds = bounds.outset(by: gap),
                aligned = bounds.alignedPoint(at: align)
            switch align {
            case .topLeading:
                $0.move(to: aligned + .unitX * size)
                $0.addLine(to: aligned)
                $0.addLine(to: aligned + .unitY * size)
            case .topTrailing:
                $0.move(to: aligned - .unitX * size)
                $0.addLine(to: aligned)
                $0.addLine(to: aligned + .unitY * size)
            case .bottomLeading:
                $0.move(to: aligned + .unitX * size)
                $0.addLine(to: aligned)
                $0.addLine(to: aligned - .unitY * size)
            case .bottomTrailing:
                $0.move(to: aligned - .unitX * size)
                $0.addLine(to: aligned)
                $0.addLine(to: aligned - .unitY * size)
            default: break
            }
        }
        .stroke(.blue, style: .init(lineWidth: 3, lineCap: .round, lineJoin: .round))
        .allowsHitTesting(false)
    }

    @ViewBuilder func touchable(bounds: CGRect, align: PlaneInnerAlign) -> some View {
        let bounds = bounds.outset(by: gap),
            aligned = bounds.alignedPoint(at: align),
            rect = CGRect(center: aligned, size: .init(squared: touchableSize))
        Rectangle()
            .fill(debugActiveSymbol ? .blue.opacity(0.1) : .invisibleSolid)
            .framePosition(rect: rect)
            .multipleGesture(global.gesture(symbolId: symbolId, align: align))
            .allowsHitTesting(visible(bounds: bounds))
    }
}
