import SwiftUI
import UniformTypeIdentifiers

private struct Context {
    var itemMap: ItemMap
    var pathMap: PathMap
    var depthMap: [UUID: Int]
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

        var body: some View { trace {
            setupSelector {
                content
            }
        } }
    }
}

// MARK: private

private extension ItemPanel.Items {
    var content: some View {
        PanelSection(name: "Items") {
            ForEach(selector.rootIds) {
                ItemPanel.ItemRow(context: context, itemId: $0)
                if $0 != selector.rootIds.last {
                    ContextualDivider()
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

    let context: Context, group: ItemGroup

    @State private var expanded = true

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
            ForEach(group.members) {
                ItemPanel.ItemRow(context: context, itemId: $0)
                    .id($0)
                if $0 != group.members.last {
                    ContextualDivider()
                }
            }
        }
        .background(depth % 2 == 0 ? Color.tertiarySystemBackground : Color.secondarySystemBackground)
        .clipRounded(radius: 12)
        .padding(.leading, 6)
    }
}

struct ColorItem: Codable, Transferable {
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(for: ColorItem.self, contentType: .item)
    }
}

struct DragRelocateDelegate: DropDelegate {
    var size: CGSize = .zero
    @Binding var hovering: Bool

    func performDrop(info: DropInfo) -> Bool {
        hovering = false
        let providers = info.itemProviders(for: [.item])
        providers.first?.loadTransferable(type: ColorItem.self) { print("dbg2", $0) }
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        let providers = info.itemProviders(for: [.item])
        print("dbg", info, providers, providers.first)
        return DropProposal(operation: .move)
    }

    func dropEntered(info _: DropInfo) {
        hovering = true
    }

    func dropExited(info _: DropInfo) {
        hovering = false
    }
}

// MARK: - PathRow

private struct PathRow: View, TracedView {
    let context: Context, pathId: UUID

    @State private var size: CGSize = .zero
    @State private var hovering: Bool = false

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
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .invisibleSoildOverlay()
                .border(hovering ? .red : .clear)
                .sizeReader { size = $0 }
                .draggable(ColorItem())
                .onDrop(of: [.item], delegate: DragRelocateDelegate(size: size, hovering: $hovering))
            menu
        }
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
