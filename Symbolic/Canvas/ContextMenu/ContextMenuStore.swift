import SwiftUI

// MARK: - ContextMenuData

enum ContextMenuData: SelfIdentifiable {
    case pathFocusedPart
    case focusedPath
    case focusedGroup
    case selection
}

// MARK: - ContextMenuStore

class ContextMenuStore: Store {
    @Trackable var menus = Set<ContextMenuData>()
    @Trackable var hidden: Bool = false
}

extension ContextMenuStore {
    func register(_ data: ContextMenuData) {
        update { $0(\._menus, menus.cloned { $0.insert(data) }) }
    }

    func deregister(_ data: ContextMenuData) {
        update { $0(\._menus, menus.cloned { $0.remove(data) }) }
    }

    func clear() {
        update { $0(\._menus, []) }
    }

    func setHidden(_ hidden: Bool) {
        update { $0(\._hidden, hidden) }
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
