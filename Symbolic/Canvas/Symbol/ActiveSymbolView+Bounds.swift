import SwiftUI

// MARK: - global actions

private extension GlobalStores {
    func onTap(symbolId: UUID) {
        activeSymbol.edit(id: symbolId)
        viewportUpdater.zoomToEditingSymbol()
    }

    func onDrag(symbolId: UUID, _ v: PanInfo, pending: Bool = false) {
        let offset = v.offset.applying(viewport.viewToWorld),
            symbolIds = activeSymbol.selected(id: symbolId) ? activeSymbol.selectedSymbolIds : [symbolId]
        documentUpdater.update(symbol: .move(.init(symbolIds: symbolIds, offset: offset)), pending: pending)
    }

    func gesture(symbolId: UUID) -> MultipleTouchGesture {
        .init(
            onPress: { _ in
                canvasAction.start(continuous: .moveSymbol)
            },
            onPressEnd: { cancelled in
                canvasAction.end(continuous: .moveSymbol)
                if cancelled { documentUpdater.cancel() }
            },

            onTap: { _ in onTap(symbolId: symbolId) },
            onDrag: { onDrag(symbolId: symbolId, $0, pending: true) },
            onDragEnd: { onDrag(symbolId: symbolId, $0) },

            onPinch: {
                canvasAction.start(continuous: .pinchViewport)
                viewportUpdater.onPinch($0)
            },
            onPinchEnd: { _ in
                canvasAction.end(continuous: .pinchViewport)
                viewportUpdater.onCommit()
            }
        )
    }
}

// MARK: - Bounds

extension ActiveSymbolView {
    struct Bounds: View, TracedView, EquatableBy, ComputedSelectorHolder {
        @Environment(\.sizedViewport) var viewport

        let symbolId: UUID

        var equatableBy: some Equatable { symbolId }

        struct SelectorProps: Equatable { let symbolId: UUID }
        class Selector: SelectorBase {
            override var configs: SelectorConfigs { .syncNotify }
            @Selected({ global.symbol.get(id: $0.symbolId)?.boundingRect }) var bounds
            @Selected({ global.activeSymbol.selectedSymbolIds.contains($0.symbolId) }) var selected
            @Selected({ global.activeSymbol.focusedSymbolId == $0.symbolId }) var focused
            @Selected({ global.activeSymbol.editingSymbolId == $0.symbolId }) var editing
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

extension ActiveSymbolView.Bounds {
    @ViewBuilder var content: some View {
        if let bounds = selector.bounds {
            if selector.editing {
                let bounds = bounds.applying(viewport.worldToView).outset(by: ActiveSymbolService.editingBoundsOutset)
                RoundedRectangle(cornerRadius: ActiveSymbolService.editingBoundsRadius)
                    .stroke(.blue.opacity(0.8))
                    .framePosition(rect: bounds)
            } else {
                let bounds = bounds.applying(viewport.worldToView)
                RoundedRectangle(cornerRadius: 2)
                    .fill(.blue.opacity(selector.focused ? 0.2 : 0.1))
                    .stroke(.blue.opacity(selector.focused ? 0.8 : 0.5))
                    .multipleTouchGesture(global.gesture(symbolId: symbolId))
                    .framePosition(rect: bounds)
            }
        }
    }
}
