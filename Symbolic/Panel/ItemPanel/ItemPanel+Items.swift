import SwiftUI
import UniformTypeIdentifiers

private struct Context {
    var itemMap: ItemMap
    var pathMap: PathMap
    var depthMap: [UUID: Int]
}

// MARK: - Model

private class Model: ObservableObject {
    @Published var draggingItemHovering: DraggingItemHovering?
}

// MARK: - DraggingItem

private struct DraggingItemHovering: Equatable, Hashable {
    var itemId: UUID
    var isAfter: Bool
}

private struct DraggingItemHoveringIndicator: View {
    @EnvironmentObject var model: Model
    var members: [UUID]
    var index: Int

    var body: some View {
        content
            .allowsHitTesting(false)
    }

    @ViewBuilder var content: some View {
        if let hovering = model.draggingItemHovering {
            let itemId = members[index]
            VStack(spacing: 0) {
                if index == 0, hovering == .init(itemId: itemId, isAfter: false) {
                    rect
                }
                Spacer()
                if hovering == .init(itemId: itemId, isAfter: true) || members.indices.contains(index + 1) && hovering == .init(itemId: members[index + 1], isAfter: false) {
                    rect
                }
            }
        }
    }

    @ViewBuilder var rect: some View {
        Rectangle()
            .fill(.blue)
            .frame(maxWidth: .infinity, maxHeight: 2)
            .padding(.leading, 12)
    }
}

private struct DraggingItemTransferable: Codable, Transferable {
    let itemId: UUID

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(for: DraggingItemTransferable.self, contentType: .item)
    }
}

private struct DraggingItemDropDelegate: DropDelegate {
    @ObservedObject var model: Model
    var itemId: UUID
    var size: CGSize = .zero

    func isAfter(info: DropInfo) -> Bool {
        info.location.y > size.height / 2
    }

    func dropEntered(info: DropInfo) {
        model.draggingItemHovering = .init(itemId: itemId, isAfter: isAfter(info: info))
    }

    func dropExited(info _: DropInfo) {
        model.draggingItemHovering = nil
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        model.draggingItemHovering = .init(itemId: itemId, isAfter: isAfter(info: info))
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        model.draggingItemHovering = nil
        let isAfter = isAfter(info: info)
        let providers = info.itemProviders(for: [.item])
        guard let provider = providers.first else { return true }
        let itemId = itemId
        _ = provider.loadTransferable(type: DraggingItemTransferable.self) { result in
            guard let transferable = try? result.get() else { return }
            Task { @MainActor in
                global.documentUpdater.update(item: .move(.init(itemId: transferable.itemId, toItemId: itemId, isAfter: isAfter)))
            }
        }
        return true
    }
}

// MARK: - Items

extension ItemPanel {
    struct Items: View, TracedView, SelectorHolder {
        class Selector: SelectorBase {
            @Selected({ global.item.rootIds }) var rootIds
            @Selected({ global.item.map }) var itemMap
            @Selected({ global.path.map }) var pathMap
            @Selected({ global.item.depthMap }) var depthMap
        }

        @SelectorWrapper var selector

        @StateObject fileprivate var model = Model()

        var body: some View { trace {
            setupSelector {
                content
                    .environmentObject(model)
            }
        } }
    }
}

// MARK: private

private extension ItemPanel.Items {
    var content: some View {
        PanelSection(name: "Items") {
            let rootIds = selector.rootIds
            ForEach(Array(zip(rootIds.indices, rootIds)), id: \.1) { index, itemId in
                VStack(spacing: 0) {
                    ItemPanel.ItemRow(context: context, itemId: itemId)
                    if itemId != rootIds.last {
                        ContextualDivider()
                    }
                }
                .overlay {
                    DraggingItemHoveringIndicator(members: rootIds, index: index)
                }
            }
        }
    }

    var context: Context {
        .init(itemMap: selector.itemMap, pathMap: selector.pathMap, depthMap: selector.depthMap)
    }
}

// MARK: - ItemRow

private extension ItemPanel {
    struct ItemRow: View, TracedView {
        let context: Context, itemId: UUID

        var body: some View { trace {
            content
                .id(itemId)
        } }
    }
}

// MARK: private

extension ItemPanel.ItemRow {
    @ViewBuilder private var content: some View {
        if let pathId = item?.pathId {
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
    @EnvironmentObject var model: Model

    let context: Context, group: ItemGroup

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
        .draggable(DraggingItemTransferable(itemId: group.id))
        .onDrop(of: [.item], delegate: DraggingItemDropDelegate(model: model, itemId: group.id, size: size))
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
    }

    var expandButton: some View {
        Button {
            withAnimation { expanded.toggle() }
        } label: {
            Image(systemName: expanded ? "chevron.up" : "chevron.down")
                .frame(maxHeight: .infinity)
        }
        .tint(.label)
    }

    var menu: some View {
        Menu {
            Button("some action") {}
        } label: {
            Image(systemName: "ellipsis")
                .frame(maxHeight: .infinity)
        }
        .tint(.label)
        .contextualFont()
    }

    var depth: Int { context.depthMap[group.id] ?? 0 }

    var members: some View {
        VStack(spacing: 0) {
            let members = group.members
            ForEach(Array(zip(members.indices, members)), id: \.1) { index, itemId in
                VStack(spacing: 0) {
                    ItemPanel.ItemRow(context: context, itemId: itemId)
                    if itemId != members.last {
                        ContextualDivider()
                    }
                }
                .overlay {
                    DraggingItemHoveringIndicator(members: members, index: index)
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
    @EnvironmentObject var model: Model
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
        .draggable(DraggingItemTransferable(itemId: pathId))
        .onDrop(of: [.item], delegate: DraggingItemDropDelegate(model: model, itemId: pathId, size: size))
    }

    var path: Path? { context.pathMap[pathId] }

    @ViewBuilder var name: some View {
        if let path {
            HStack(spacing: 6) {
                PathThumbnail(path: path)
                Text(pathId.shortDescription)
            }
            .contextualFont()
        }
    }

    var menu: some View {
        Menu {
            Button("some action") {}
        } label: {
            Image(systemName: "ellipsis")
                .frame(maxHeight: .infinity)
        }
        .tint(.label)
        .contextualFont()
    }
}
