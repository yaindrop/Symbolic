import Foundation

private let subtracer = tracer.tagged("RootStore")

enum RootNavigationValue: CaseIterable, SelfIdentifiable {
    case documents
    case deleted
}

// MARK: - RootStore

class RootStore: Store {
    @Trackable var rootPanLocation: Point2?

    @Trackable var selected: RootNavigationValue = .documents

    @Trackable var navigationSize: CGSize = .zero
    @Trackable var detailSize: CGSize = .zero
}

private extension RootStore {
    func update(selected: RootNavigationValue) {
        update { $0(\._selected, selected) }
    }

    func update(navigationSize: CGSize) {
        update { $0(\._navigationSize, navigationSize) }
    }

    func update(detailSize: CGSize) {
        update { $0(\._detailSize, detailSize) }
    }
}

// MARK: actions

extension RootStore {
    func update(rootPanLocation: Point2?) {
        update { $0(\._rootPanLocation, rootPanLocation) }
    }

    func setSelected(_ selected: RootNavigationValue) {
        update(selected: selected)
    }

    func setNavigationSize(_ navigationSize: CGSize) {
        update(navigationSize: navigationSize)
    }

    func setDetailSize(_ detailSize: CGSize) {
        update(detailSize: detailSize)
    }
}
