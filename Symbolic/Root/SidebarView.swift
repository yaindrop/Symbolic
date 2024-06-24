import SwiftUI

enum SidebarNavigationValue: CaseIterable, SelfIdentifiable {
    case documents, deleted
}

struct SidebarView: View, TracedView {
    @State private var selection: SidebarNavigationValue = .documents

    var body: some View { trace {
        content
    } }
}

private extension SidebarView {
    @ViewBuilder var content: some View {
        ScrollView {
            VStack {
                ForEach(SidebarNavigationValue.allCases) {
                    SidebarItem(value: $0, selection: selection)
                }
            }
            .padding()
        }
        .navigationDestination(for: SidebarNavigationValue.self) { value in
            switch value {
            case .documents: DocumentsView().onAppear { selection = value }
            case .deleted: DeletedView().onAppear { selection = value }
            }
        }
        .navigationTitle("Symbolic")
    }
}

struct SidebarItem: View {
    let value: SidebarNavigationValue
    let selection: SidebarNavigationValue

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
