import Foundation
import SwiftUI

// MARK: - ItemPanel

struct ItemPanel: View {
    let panelId: UUID

    var body: some View { tracer.range("ItemPanel body") {
        content
            .frame(width: 320)
    } }
    

    // MARK: private

    @Selected private var rootIds = global.item.rootIds

    @StateObject private var scrollViewModel = ManagedScrollViewModel()

    @ViewBuilder private var content: some View {
        VStack(spacing: 0) {
            PanelTitle(name: "Items")
                .if(scrollViewModel.scrolled) { $0.background(.regularMaterial) }
                .invisibleSoildOverlay()
                .multipleGesture(global.panel.moveGesture(panelId: panelId))
            scrollView
        }
        .background(.ultraThinMaterial)
        .clipRounded(radius: 12)
    }

    @ViewBuilder private var scrollView: some View {
        ManagedScrollView(model: scrollViewModel) { _ in
            items
        }
        .frame(maxHeight: 400)
        .fixedSize(horizontal: false, vertical: true)
        .scrollBounceBehavior(.basedOnSize, axes: [.vertical])
    }

    @ViewBuilder private var items: some View {
        VStack(spacing: 4) {
            PanelSectionTitle(name: "Items")
            VStack(spacing: 0) {
                ForEach(rootIds) {
                    ItemRow(itemId: $0)
                    if $0 != rootIds.last {
                        Divider()
                    }
                }
            }
            .background(.ultraThickMaterial)
            .clipRounded(radius: 12)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 24)
    }
}

// MARK: - ItemRow

extension ItemPanel {
    struct ItemRow: View, EquatableBy {
        let itemId: UUID

        var equatableBy: some Equatable { itemId }

        var body: some View { tracer.range("ItemRow body") {
            content
                .compute(_item, itemId)
        } }
        
        init(itemId: UUID) {
            self.itemId = itemId
            _item(itemId)
            print("dbgdbg", item)
        }

        // MARK: private

        @Computed({ (itemId: UUID) in global.item.item(id: itemId) })
        private var item: Item? = nil

        @ViewBuilder var content: some View {
            if let pathId = item?.pathId {
                PathRow(pathId: pathId)
            } else if let group = item?.group {
                GroupRow(group: group)
            }
        }
    }
}

// MARK: - GroupRow

extension ItemPanel {
    struct GroupRow: View, EquatableBy {
        let group: ItemGroup

        var equatableBy: some Equatable { group }

        var body: some View { tracer.range("GroupRow body") {
            content
                .compute(_depth, group.id)
        } }

        // MARK: private

        @Computed({ (itemId: UUID) in global.item.depth(itemId: itemId) })
        private var depth: Int = 0

        @State private var expanded = true

        private var content: some View {
            VStack {
                row
                if expanded {
                    members
                }
            }
        }

        private var row: some View {
            HStack {
                name
                Spacer()
                menu
            }
        }

        private var name: some View {
            HStack {
                expandButton
                    .padding(4)
                Text(group.id.shortDescription)
                    .font(.subheadline)
            }
            .padding(12)
        }

        private var expandButton: some View {
            Button {
                withAnimation { expanded.toggle() }
            } label: {
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .frame(width: 24, height: 24)
            }
            .tint(.label)
        }

        private var menu: some View {
            Menu {
                Button("some action") {}
            } label: {
                Image(systemName: "ellipsis")
                    .padding(.horizontal, 12)
                    .frame(maxHeight: .infinity)
            }
            .tint(.label)
        }

        private var members: some View {
            HStack(spacing: 0) {
                VStack {
                    ForEach(group.members) {
                        ItemRow(itemId: $0)
                            .id($0)
                    }
                }
                .if(depth < 5) { $0.background(.secondary) }
                .clipRounded(radius: 12, border: depth < 5 ? Color.clear : Color.label)
                .padding(.leading, 12)
            }
        }
    }
}

// MARK: - PathRow

extension ItemPanel {
    struct PathRow: View {
        let pathId: UUID

        var body: some View { tracer.range("PathRow body") {
            content
                .compute(_path, pathId)
        } }
        
        init(pathId: UUID) {
            self.pathId = pathId
            _path(pathId)
            print("dbgdbg", path)
        }

        // MARK: private

        @Computed({ (pathId: UUID) in global.path.path(id: pathId) })
        private var path: Path? = nil

        private struct PathThumbnail: View {
            let path: Path

            static let size = CGSize(24, 24)

            var body: some View { tracer.range("PathThumbnail body") {
                Rectangle()
                    .opacity(.zero)
                    .overlay {
                        SUPath { path.append(to: &$0) }
                            .transform(.init(fit: path.boundingRect, to: .init(Self.size)))
                            .stroke(.primary, lineWidth: 0.5)
                            .fill(.primary.opacity(0.2))
                    }
                    .frame(size: Self.size)
            } }
        }

        @ViewBuilder private var content: some View {
            HStack {
                name
                Spacer()
                menu
            }
        }

        @ViewBuilder private var name: some View {
            if let path {
                HStack {
                    PathThumbnail(path: path)
                        .padding(4)
                    Text(pathId.shortDescription)
                        .font(.subheadline)
                }
                .padding(12)
            }
        }

        private var menu: some View {
            Menu {
                Button("some action") {}
            } label: {
                Image(systemName: "ellipsis")
                    .padding(.horizontal, 12)
                    .frame(maxHeight: .infinity)
            }
            .tint(.label)
        }
    }
}
