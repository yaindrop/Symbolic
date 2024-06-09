import SwiftUI

// MARK: - ContextMenuData

enum ContextMenuData: HashIdentifiable {
    case pathFocusedPart
    case focusedPath
    case focusedGroup
    case selection
}

// MARK: - ContextMenuStore

class ContextMenuStore: Store {
    @Trackable var menus = Set<ContextMenuData>()

    func register(_ data: ContextMenuData) {
        update { $0(\._menus, menus.with { $0.insert(data) }) }
    }

    func deregister(_ data: ContextMenuData) {
        update { $0(\._menus, menus.with { $0.remove(data) }) }
    }

    @ViewBuilder func representative(_ data: ContextMenuData) -> some View {
        Color.clear
            .onAppear { self.register(data) }
            .onDisappear { self.deregister(data) }
            .onChange(of: data) {
                self.deregister($0)
                self.register($1)
            }
    }
}
