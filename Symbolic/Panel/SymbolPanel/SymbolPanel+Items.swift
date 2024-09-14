import SwiftUI
import UniformTypeIdentifiers

private struct Context {
    var itemMap: ItemMap
    var pathMap: PathMap
    var itemDepthMap: [UUID: Int]
    var focusedItemId: UUID?
    var selectedItemIds: Set<UUID>
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
            ForEach(Array(zip(rootIds.indices, rootIds)), id: \.1) { index, itemId in
                VStack(spacing: 0) {
                    SymbolPanel.ItemRow(context: context, itemId: itemId)
                    if itemId != rootIds.last {
                        ContextualDivider()
                    }
                }
                .overlay {
                    if context.selectedItemIds.contains(itemId) {
                        SelectedIndicator()
                    }
                }
                .overlay {
                    DndListHoveringIndicator(members: rootIds, index: index)
                }
            }
        }
    }

    var context: Context {
        .init(itemMap: selector.itemMap, pathMap: selector.pathMap, itemDepthMap: selector.itemDepthMap, focusedItemId: selector.focusedItemId, selectedItemIds: selector.selectedItemIds)
    }
}

// MARK: - ItemRow

private extension SymbolPanel {
    struct ItemRow: View, TracedView {
        let context: Context, itemId: UUID

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
            PathRow(context: context, pathId: pathId)
        } else if let group = item?.group {
            GroupRow(context: context, group: group)
        }
    }

    var item: Item? { context.itemMap[itemId] }
}

// MARK: - GroupRow

private struct GroupRow: View, TracedView {
    @Environment(\.contextualViewData) var contextualViewData
    @EnvironmentObject var dndListModel: DndListModel

    let context: Context, group: Item.Group

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
        .onDrop(of: [.item], delegate: DndListDropDelegate(model: dndListModel, id: group.id, size: size) { itemId, isAfter in
            global.documentUpdater.update(item: .reorder(.init(itemId: itemId, toItemId: group.id, isAfter: isAfter)))
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
        .foregroundStyle(context.focusedItemId == group.id ? .blue : .label)
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
            Button("Focus") {
                global.activeItem.focus(itemId: group.id)
                guard let bounds = global.item.boundingRect(of: group.id) else { return }
                global.viewportUpdater.zoomTo(worldRect: bounds.applying(global.activeSymbol.symbolToWorld), ratio: 0.5)
            }
        } label: {
            Image(systemName: "ellipsis")
                .frame(maxHeight: .infinity)
        }
        .tint(.label)
        .contextualFont()
    }

    var depth: Int { context.itemDepthMap[group.id] ?? 0 }

    var members: some View {
        VStack(spacing: 0) {
            let members = group.members
            ForEach(Array(zip(members.indices, members)), id: \.1) { index, itemId in
                VStack(spacing: 0) {
                    SymbolPanel.ItemRow(context: context, itemId: itemId)
                    if itemId != members.last {
                        ContextualDivider()
                    }
                }
                .overlay {
                    if context.selectedItemIds.contains(itemId) {
                        SelectedIndicator()
                    }
                }
                .overlay {
                    DndListHoveringIndicator(members: members, index: index)
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
    let context: Context, pathId: UUID

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
        .onDrop(of: [.item], delegate: DndListDropDelegate(model: dndListModel, id: pathId, size: size) { itemId, isAfter in
            global.documentUpdater.update(item: .reorder(.init(itemId: itemId, toItemId: pathId, isAfter: isAfter)))
        })
    }

    var path: Path? { context.pathMap[pathId] }

    @ViewBuilder var name: some View {
        if let path {
            HStack(spacing: 6) {
                PathThumbnail(path: path)
                Text(pathId.shortDescription)
            }
            .contextualFont()
            .foregroundStyle(context.focusedItemId == pathId ? .blue : .label)
        }
    }

    var menu: some View {
        Menu {
            Button("Focus") {
                global.activeItem.focus(itemId: pathId)
                guard let bounds = global.item.boundingRect(of: pathId) else { return }
                global.viewportUpdater.zoomTo(worldRect: bounds.applying(global.activeSymbol.symbolToWorld), ratio: 0.5)
            }
        } label: {
            Image(systemName: "ellipsis")
                .frame(maxHeight: .infinity)
        }
        .tint(.label)
        .contextualFont()
    }
}
