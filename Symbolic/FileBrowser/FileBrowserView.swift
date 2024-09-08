import SwiftUI

// MARK: - FileBrowserView

struct FileBrowserView: View, TracedView, SelectorHolder {
    class Selector: SelectorBase {
        @Selected({ global.fileBrowser.directories }, .animation(.fast)) var directories
        @Selected({ global.root.detailSize }) var detailSize
    }

    @SelectorWrapper var selector

    var body: some View { trace {
        setupSelector {
            content
        }
    } }
}

// MARK: private

private extension FileBrowserView {
    @ViewBuilder var content: some View {
        ZStack {
            let directories = selector.directories
            ForEach(Array(zip(directories.indices, directories)), id: \.1.url.path) { index, entry in
                let isTop = entry == directories.last
                FileDirectoryView(entry: entry)
                    .offset(isTop ? .zero : .init(Vector2(-selector.detailSize.width, 0)))
                    .overlay(isTop ? .clear : .secondarySystemBackground.opacity(0.5))
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .trailing)))
                    .zIndex(.init(index)) // exiting transition works only when z-index is set
            }
        }
        .modifier(ToolbarModifier())
    }
}

// MARK: - ToolbarModifier

private struct ToolbarModifier: ViewModifier, SelectorHolder {
    class Selector: SelectorBase {
        @Selected({ global.fileBrowser.isSelectingFiles }, .animation(.fast)) var isSelectingFiles
        @Selected({ global.viewport.viewSize }, .alwaysNotify) var viewSize
    }

    @SelectorWrapper var selector

    func body(content: Content) -> some View {
        setupSelector {
            let _ = selector.viewSize // strange bug that toolbar is lost when window size changes, need to reset ids
            content.toolbar { toolbar }
        }
    }
}

private extension ToolbarModifier {
    @ToolbarContentBuilder var toolbar: some ToolbarContent {
        ToolbarItem(id: UUID().uuidString, placement: .topBarLeading) { leading }
        ToolbarItem(id: UUID().uuidString, placement: .topBarTrailing) { trailing }
        if selector.isSelectingFiles {
            ToolbarItem(id: UUID().uuidString, placement: .bottomBar) { bottomBar }
        }
    }

    var leading: some View {
        HStack {
            Button {
                global.fileBrowser.directoryBack()
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(global.fileBrowser.directoryPath.isEmpty)
            .frame(size: .init(squared: 36))
            Button {
                global.fileBrowser.directoryForward()
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(global.fileBrowser.forwardPath.isEmpty)
            .frame(size: .init(squared: 36))
        }
    }

    var trailing: some View {
        HStack {
            Button {
                guard let entry = global.fileBrowser.directories.last else { return }
                global.fileBrowser.newDocument(in: entry)
            } label: { Image(systemName: "doc.badge.plus") }
                .frame(size: .init(squared: 36))
            Button {
                guard let entry = global.fileBrowser.directories.last else { return }
                global.fileBrowser.newDirectory(in: entry)
            } label: { Image(systemName: "folder.badge.plus") }
                .frame(size: .init(squared: 36))
            Button {
                global.fileBrowser.toggleSelecting()
            } label: { Text(LocalizedStringKey(selector.isSelectingFiles ? "button_done" : "button_select")) }
        }
    }

    var bottomBar: some View {
        HStack {
            Button("Duplicate") {}
            Spacer()
            Button("Move") {}
            Spacer()
            Button("Delete") {
                global.fileBrowser.moveToDeleted(at: .init(global.fileBrowser.selectedFiles))
            }
        }
    }
}
