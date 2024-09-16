import SwiftUI

// MARK: - global actions

private extension GlobalStores {
    func focus(id: UUID) {
        guard let symbol = symbol.get(id: id) else { return }
        activeSymbol.focus(id: id)
        viewportUpdater.zoomTo(worldRect: symbol.boundingRect, ratio: 0.5)
    }

    func reorder(itemId: UUID, toItemId: UUID, isAfter: Bool) {
        documentUpdater.update(item: .reorder(.init(itemId: itemId, toItemId: toItemId, isAfter: isAfter)))
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

extension SymbolPanel {
    struct Items: View, TracedView, SelectorHolder {
        class Selector: SelectorBase {
            @Selected({ global.path.pathMap }) var pathMap
            @Selected({ global.item.itemMap }) var itemMap
            @Selected({ global.item.itemDepthMap }) var itemDepthMap
            @Selected({ global.activeSymbol.focusedSymbolItem?.symbol?.members ?? [] }) var rootIds
            @Selected({ global.activeItem.focusedItemId }) var focusedItemId
            @Selected({ global.activeItem.selectedItemIds }) var selectedItemIds
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

private extension SymbolPanel.Items {
    var content: some View {
        PanelSection(name: "Items") {
            let rootIds = selector.rootIds
            ForEach(rootIds) { itemId in
                VStack(spacing: 0) {
                    SymbolPanel.ItemRow(itemId: itemId)
                    if itemId != rootIds.last {
                        ContextualDivider()
                    }
                }
                .overlay {
                    SelectedIndicator()
                        .opacity(selector.selectedItemIds.contains(itemId) ? 1 : 0)
                }
                .overlay {
                    DndListHoveringIndicator(id: itemId, members: rootIds)
                }
            }
        }
    }
}

// MARK: - ItemRow

private extension SymbolPanel {
    struct ItemRow: View, TracedView {
        @EnvironmentObject var selector: SymbolPanel.Items.Selector
        let itemId: UUID

        var body: some View { trace {
            content
                .id(itemId)
        } }
    }
}

// MARK: private

extension SymbolPanel.ItemRow {
    @ViewBuilder private var content: some View {
        if let pathId = item?.path?.id {
            PathRow(pathId: pathId)
        } else if let group = item?.group {
            GroupRow(group: group)
        }
    }

    var item: Item? { selector.itemMap.get(itemId) }
}

// MARK: - GroupRow

private struct GroupRow: View, TracedView {
    @Environment(\.contextualViewData) var contextualViewData
    @EnvironmentObject var selector: SymbolPanel.Items.Selector
    @EnvironmentObject var dndListModel: DndListModel

    let group: Item.Group

    @State private var expanded = true
    @State private var size: CGSize = .zero

    var body: some View { trace {
        content
    } }
}

// MARK: private

private extension GroupRow {
    var content: some View {
        ContextualRow(limited: false, padding: rowPadding) {
            VStack(spacing: 6) {
                HStack {
                    name
                    Spacer()
                    menu
                }
                .frame(height: rowHeight)
                .padding(.trailing, contextualViewData.rowPadding.trailing)
                if expanded {
                    members
                }
            }
        }
        .sizeReader { size = $0 }
        .invisibleSoildBackground()
        .draggable(DndListTransferable(id: group.id))
        .onDrop(of: [.item], delegate: DndListDropDelegate(model: dndListModel, id: group.id, size: size) {
            global.reorder(itemId: $0, toItemId: group.id, isAfter: $1)
        })
    }

    var rowHeight: Scalar { contextualViewData.rowHeight }

    var rowPadding: EdgeInsets {
        var rowPadding = contextualViewData.rowPadding
        rowPadding.trailing = 0
        return rowPadding
    }

    var name: some View {
        HStack(spacing: 6) {
            expandButton
            Text(group.id.shortDescription)
        }
        .contextualFont()
        .foregroundStyle(selector.focusedItemId == group.id ? .blue : .label)
    }

    var expandButton: some View {
        Button {
            withAnimation { expanded.toggle() }
        } label: {
            Image(systemName: expanded ? "chevron.up" : "chevron.down")
                .frame(minWidth: 24, maxHeight: .infinity)
        }
        .tint(.label)
    }

    var menu: some View {
        Menu {
            Button("Focus") { global.focus(id: group.id) }
        } label: {
            Image(systemName: "ellipsis")
                .frame(maxHeight: .infinity)
        }
        .tint(.label)
        .contextualFont()
    }

    var depth: Int { selector.itemDepthMap.get(group.id) ?? 0 }

    var members: some View {
        VStack(spacing: 0) {
            let members = group.members
            ForEach(members) { itemId in
                VStack(spacing: 0) {
                    SymbolPanel.ItemRow(itemId: itemId)
                    if itemId != members.last {
                        ContextualDivider()
                    }
                }
                .overlay {
                    SelectedIndicator()
                        .opacity(selector.selectedItemIds.contains(itemId) ? 1 : 0)
                }
                .overlay {
                    DndListHoveringIndicator(id: itemId, members: members)
                }
            }
        }
        .background(depth % 2 == 0 ? Color.tertiarySystemBackground : Color.secondarySystemBackground)
        .clipRounded(radius: 12)
        .padding(.leading, 6)
    }
}

// MARK: - PathRow

private struct PathRow: View, TracedView {
    @EnvironmentObject var dndListModel: DndListModel
    @EnvironmentObject var selector: SymbolPanel.Items.Selector
    let pathId: UUID

    @State private var size: CGSize = .zero

    var body: some View { trace {
        content
    } }
}

// MARK: private

private extension PathRow {
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
        .draggable(DndListTransferable(id: pathId))
        .onDrop(of: [.item], delegate: DndListDropDelegate(model: dndListModel, id: pathId, size: size) {
            global.reorder(itemId: $0, toItemId: pathId, isAfter: $1)
        })
    }

    var path: Path? { selector.pathMap.get(pathId) }

    @ViewBuilder var name: some View {
        if let path {
            HStack(spacing: 6) {
                PathThumbnail(path: path)
                Text(pathId.shortDescription)
            }
            .contextualFont()
            .foregroundStyle(selector.focusedItemId == pathId ? .blue : .label)
        }
    }

    var menu: some View {
        Menu {
            Button("Focus") { global.focus(id: pathId) }
        } label: {
            Image(systemName: "ellipsis")
                .frame(maxHeight: .infinity)
        }
        .tint(.label)
        .contextualFont()
    }
}
