import SwiftUI

// MARK: - global actions

private extension GlobalStores {
    func focus(id: UUID) {
        guard let bounds = item.boundingRect(of: id) else { return }
        activeItem.focus(id: id)
        viewportUpdater.zoomTo(worldRect: bounds.applying(activeSymbol.symbolToWorld), ratio: 0.5)
    }

    func reorder(symbolId: UUID, toSymbolId: UUID, isAfter: Bool) {
        documentUpdater.update(world: .reorder(.init(symbolId: symbolId, toSymbolId: toSymbolId, isAfter: isAfter)))
    }
}

private struct SelectedIndicator: View {
    var body: some View {
        content
    }

    @ViewBuilder var content: some View {
        HStack(spacing: 0) {
            rect
            Spacer()
        }
    }

    @ViewBuilder var rect: some View {
        Rectangle()
            .fill(.blue)
            .frame(maxWidth: 2, maxHeight: .infinity)
            .allowsHitTesting(false)
    }
}

// MARK: - Items

extension DocumentPanel {
    struct Symbols: View, TracedView, SelectorHolder {
        class Selector: SelectorBase {
            @Selected({ global.world.symbolIds }) var symbolIds
            @Selected({ global.activeSymbol.focusedSymbolId }) var focusedSymbolId
            @Selected({ global.activeSymbol.selectedSymbolIds }) var selectedSymbolIds
        }

        @SelectorWrapper var selector

        @StateObject fileprivate var dndListModel = DndListModel()

        var body: some View { trace {
            setupSelector {
                content
                    .environmentObject(selector)
                    .environmentObject(dndListModel)
            }
        } }
    }
}

// MARK: private

private extension DocumentPanel.Symbols {
    var content: some View {
        PanelSection(name: "Symbols") {
            let symbolIds = selector.symbolIds
            ForEach(symbolIds) { symbolId in
                VStack(spacing: 0) {
                    SymbolRow(symbolId: symbolId)
                    if symbolId != symbolIds.last {
                        ContextualDivider()
                    }
                }
                .overlay {
                    SelectedIndicator()
                        .opacity(selector.selectedSymbolIds.contains(symbolId) ? 1 : 0)
                }
                .overlay {
                    DndListHoveringIndicator(id: symbolId, members: symbolIds)
                }
            }
        }
    }
}

// MARK: - SymbolRow

private struct SymbolRow: View, TracedView {
    @EnvironmentObject var selector: DocumentPanel.Symbols.Selector
    @EnvironmentObject var dndListModel: DndListModel
    let symbolId: UUID

    @State private var size: CGSize = .zero

    var body: some View { trace {
        content
    } }
}

// MARK: private

private extension SymbolRow {
    struct PathThumbnail: View, TracedView {
        let path: Path

        var size: CGSize { .init(24, 24) }

        var body: some View { trace {
            Rectangle()
                .fill(.clear)
                .overlay {
                    SUPath { path.append(to: &$0) }
                        .transform(.init(fit: path.boundingRect, to: .init(size)))
                        .stroke(.primary.opacity(0.5), lineWidth: 0.5)
                        .fill(.primary.opacity(0.2))
                }
                .frame(size: size)
        } }
    }

    @ViewBuilder var content: some View {
        ContextualRow {
            name
            Spacer()
            menu
        }
        .sizeReader { size = $0 }
        .invisibleSoildBackground()
        .draggable(DndListTransferable(id: symbolId))
        .onDrop(of: [.item], delegate: DndListDropDelegate(model: dndListModel, id: symbolId, size: size) {
            global.reorder(symbolId: $0, toSymbolId: symbolId, isAfter: $1)
        })
    }

    @ViewBuilder var name: some View {
        HStack(spacing: 6) {
//                PathThumbnail(path: path)
            Text(symbolId.shortDescription)
        }
        .contextualFont()
        .foregroundStyle(selector.focusedSymbolId == symbolId ? .blue : .label)
    }

    var menu: some View {
        Menu {
            Button("Focus") { global.focus(id: symbolId) }
        } label: {
            Image(systemName: "ellipsis")
                .frame(maxHeight: .infinity)
        }
        .tint(.label)
        .contextualFont()
    }
}
