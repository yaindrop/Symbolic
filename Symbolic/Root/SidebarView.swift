import SwiftUI

struct SidebarView: View, TracedView {
    @State private var selection: RootNavigationValue = .documents

    var body: some View { trace {
        content
    } }
}

private extension SidebarView {
    @ViewBuilder var content: some View {
        ScrollView {
            VStack {
                ForEach(RootNavigationValue.allCases) {
                    SidebarItem(value: $0, selection: selection)
                }
            }
            .padding()
        }
        .navigationDestination(for: RootNavigationValue.self) { value in
            switch value {
            case .documents:
                DocumentsView()
                    .onAppear { selection = value }
                    .sizeReader { global.root.setDetailSize($0) }
            case .deleted:
                DeletedView()
                    .onAppear { selection = value }
                    .sizeReader { global.root.setDetailSize($0) }
            }
        }
        .navigationTitle("Symbolic")
    }
}

struct SidebarItem: View {
    let value: RootNavigationValue
    let selection: RootNavigationValue

    var imageName: String {
        switch value {
        case .documents: "folder.circle"
        case .deleted: "trash.circle"
        }
    }

    var imageTint: Color {
        switch value {
        case .documents: .blue
        case .deleted: .red
        }
    }

    var name: String {
        switch value {
        case .documents: "Documents"
        case .deleted: "Deleted"
        }
    }

    var body: some View {
        NavigationLink(value: value) {
            HStack {
                Image(systemName: imageName)
                    .font(.title)
                    .tint(imageTint)
                Text(name)
                    .font(.title3)
                Spacer()
            }
            .tint(.label)
            .padding(12)
            .background(selection == value ? Color.secondarySystemBackground : .clear)
            .clipRounded(radius: 12)
        }
    }
}
