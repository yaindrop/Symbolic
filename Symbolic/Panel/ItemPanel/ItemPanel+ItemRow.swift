import SwiftUI

// MARK: - ItemRow

extension ItemPanel {
    struct ItemRow: View, TracedView, EquatableBy, ComputedSelectorHolder {
        let itemId: UUID

        var equatableBy: some Equatable { itemId }

        struct SelectorProps: Equatable { let itemId: UUID }
        class Selector: SelectorBase {
            @Selected({ global.item.get(id: $0.itemId) }) var item
        }

        @SelectorWrapper var selector

        var body: some View { trace {
            setupSelector(.init(itemId: itemId)) {
                content
            }
        } }
    }
}

// MARK: private

extension ItemPanel.ItemRow {
    @ViewBuilder private var content: some View {
        if let pathId = selector.item?.pathId {
            PathRow(pathId: pathId)
        } else if let group = selector.item?.group {
            GroupRow(group: group)
        }
    }
}

// MARK: - GroupRow

private struct GroupRow: View, TracedView, EquatableBy, ComputedSelectorHolder {
    @Environment(\.contextualViewData) var contextualViewData

    let group: ItemGroup

    var equatableBy: some Equatable { group }

    struct SelectorProps: Equatable { let itemId: UUID }
    class Selector: SelectorBase {
        @Selected({ global.item.depth(itemId: $0.itemId) }) var depth
    }

    @SelectorWrapper var selector

    @State private var expanded = true

    var body: some View { trace {
        setupSelector(.init(itemId: group.id)) {
            content
        }
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

    var members: some View {
        VStack(spacing: 0) {
            ForEach(group.members) {
                ItemPanel.ItemRow(itemId: $0)
                    .id($0)
                if $0 != group.members.last {
                    ContextualDivider()
                }
            }
        }
        .background(selector.depth % 2 == 0 ? Color.tertiarySystemBackground : Color.secondarySystemBackground)
        .clipRounded(radius: 12)
        .padding(.leading, 6)
    }
}

// MARK: - PathRow

private struct PathRow: View, TracedView, EquatableBy, ComputedSelectorHolder {
    let pathId: UUID

    var equatableBy: some Equatable { pathId }

    struct SelectorProps: Equatable { let pathId: UUID }
    class Selector: SelectorBase {
        @Selected({ global.path.get(id: $0.pathId) }) var path
    }

    @SelectorWrapper var selector

    var body: some View { trace {
        setupSelector(.init(pathId: pathId)) {
            content
        }
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
    }

    @ViewBuilder var name: some View {
        if let path = selector.path {
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
