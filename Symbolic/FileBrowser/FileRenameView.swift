import SwiftUI

// MARK: - FileRenameView

struct FileRenameView: View {
    let entry: FileEntry

    @State private var name: String
    @State private var isValid: Bool = false

    init(entry: FileEntry) {
        self.entry = entry
        name = entry.url.name
    }

    var body: some View {
        content
            .onChange(of: name) {
                isValid = !entry.url.renaming(to: name, ext: "symbolic").exists
            }
    }
}

// MARK: private

extension FileRenameView {
    @ViewBuilder var content: some View {
        TextField("New name", text: $name)
            .textInputAutocapitalization(.never)
        Button(LocalizedStringKey("button_cancel")) {}
        Button(LocalizedStringKey("button_done")) { global.fileBrowser.rename(at: entry, name: name) }
            .disabled(!isValid)
    }
}

// MARK: - FileRenameAlertModifier

struct FileRenameAlertModifier: ViewModifier {
    let entry: FileEntry
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        content.alert("Rename \(entry.isDirectory ? "folder" : "document")", isPresented: $isPresented) {
            FileRenameView(entry: entry)
        }
    }
}
