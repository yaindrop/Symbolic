import Foundation
import SwiftUI

// MARK: - ItemPanel

struct ItemPanel: View {
    let panelId: UUID

    var body: some View {
        panel.frame(width: 320)
    }

    // MARK: private

    @Selected private var rootIds = global.item.rootIds

    @StateObject private var scrollViewModel = ManagedScrollViewModel()

    @ViewBuilder private var panel: some View {
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
            content
        }
        .frame(maxHeight: 400)
        .fixedSize(horizontal: false, vertical: true)
        .scrollBounceBehavior(.basedOnSize, axes: [.vertical])
    }

    @ViewBuilder private var content: some View {
        VStack(spacing: 4) {
            PanelSectionTitle(name: "Items")
            VStack(spacing: 12) {
                ForEach(rootIds) {
                    ItemRow(itemId: $0)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 24)
    }
}

extension ItemPanel {
    struct ItemRow: View {
        let itemId: UUID

        var body: some View {
            Group {
                if let pathId = item?.pathId {
                    PathRow(pathId: pathId)
                } else if let group = item?.group {
                    GroupRow(group: group)
                }
            }
            .if(isRoot) {
                $0.if(item?.group != nil) {
                    $0.clipRounded(radius: 12, border: .ultraThinMaterial, stroke: .init(lineWidth: 4))
                } else: {
                    $0.clipRounded(radius: 12)
                }
            } else: {
                $0.clipRounded(leading: 12, trailing: 0)
            }
        }

        init(itemId: UUID) {
            self.itemId = itemId
            _item = .init { global.item.item(id: itemId) }
            _isRoot = .init { global.item.rootIds.contains(itemId) }
        }

        @Selected private var item: Item?
        @Selected private var isRoot: Bool
    }

    struct GroupRow: View {
        let group: ItemGroup

        var body: some View {
            VStack {
                title
                if expanded {
                    members
                }
            }
            .background(.regularMaterial)
        }

        init(group: ItemGroup) {
            self.group = group
        }

        @State private var expanded = false

        private var title: some View {
            HStack {
                expandButton
                Text("#\(group.id.uuidString.prefix(4))")
                    .font(.subheadline)
                    .padding(.vertical, 12)
                Spacer()
                menu
            }
        }

        private var expandButton: some View {
            Button {
                withAnimation { expanded.toggle() }
            } label: {
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .padding(.horizontal, 12)
                    .frame(maxHeight: .infinity)
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
            VStack {
                ForEach(group.members) {
                    ItemRow(itemId: $0)
                }
            }
            .padding(.leading.union(.bottom), 12)
        }
    }

    struct PathRow: View {
        let pathId: UUID

        var body: some View {
            title
                .background(.ultraThinMaterial)
        }

        init(pathId: UUID) {
            self.pathId = pathId
            _path = .init { global.path.path(id: pathId) }
        }

        @Selected private var path: Path?

        @ViewBuilder private var title: some View {
            if let path {
                HStack {
                    HStack {
                        Image(systemName: "point.bottomleft.forward.to.point.topright.scurvepath")
                            .padding(4)
                        Text("#\(path.id.uuidString.prefix(4))")
                    }
                    .font(.subheadline)
                    .padding(12)
                    Spacer()
                    menu
                }
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
