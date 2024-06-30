import SwiftUI

// MARK: - DeletedFileBrowserView

struct DeletedFileBrowserView: View, TracedView {
    var body: some View { trace {
        content
    } }
}

// MARK: private

private extension DeletedFileBrowserView {
    @ViewBuilder var content: some View {
        FileDirectoryView(entry: .init(url: .deletedDirectory)!)
    }
}
