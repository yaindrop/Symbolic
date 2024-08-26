import SwiftUI

// MARK: - global actions

private extension GlobalStores {
    func onTap(symbolId: UUID) {
        activeSymbol.setEditing(symbolId: symbolId)
    }

    func onDrag(symbolId: UUID, _ v: PanInfo, pending: Bool = false) {
        let offset = v.offset.applying(viewport.viewToWorld)
        if activeSymbol.selected(id: symbolId) {
            let symbolIds = activeSymbol.selectedSymbolIds
            documentUpdater.update(symbol: .move(.init(symbolIds: .init(symbolIds), offset: offset)), pending: pending)
        } else {
            documentUpdater.update(symbol: .move(.init(symbolIds: [symbolId], offset: offset)), pending: pending)
        }
    }

    func gesture(symbolId: UUID) -> MultipleTouchGesture {
        .init(
            onPress: {
                canvasAction.start(continuous: .moveSelection)
            },
            onPressEnd: { cancelled in
                canvasAction.end(continuous: .moveSelection)
                if cancelled { documentUpdater.cancel() }
            },

            onTap: { _ in onTap(symbolId: symbolId) },
            onDrag: { onDrag(symbolId: symbolId, $0, pending: true) },
            onDragEnd: { onDrag(symbolId: symbolId, $0) },

            onPinch: { viewportUpdater.onPinch($0) },
            onPinchEnd: { _ in viewportUpdater.onCommit() }
        )
    }
}

// MARK: - Bounds

extension ActiveSymbolView {
    struct Bounds: View, TracedView, EquatableBy, ComputedSelectorHolder {
        let symbolId: UUID

        var equatableBy: some Equatable { symbolId }

        struct SelectorProps: Equatable { let symbolId: UUID }
        class Selector: SelectorBase {
            override var configs: SelectorConfigs { .init(syncNotify: true) }
            @Selected({ global.viewport.sizedInfo }) var viewport
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
            AnimatableReader(selector.viewport) {
                if selector.editing {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(.blue.opacity(0.8))
                        .framePosition(rect: bounds.applying($0.worldToView).outset(by: 12))
                } else {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.blue.opacity(selector.focused ? 0.2 : 0.1))
                        .stroke(.blue.opacity(selector.focused ? 0.8 : 0.5))
                        .multipleTouchGesture(global.gesture(symbolId: symbolId))
                        .framePosition(rect: bounds.applying($0.worldToView))
                }
            }
        }
    }
}
