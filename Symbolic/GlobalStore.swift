import Foundation

struct GlobalStore {
    let viewportStore = ViewportStore()
    let viewportUpdateStore = ViewportUpdateStore()
    var viewport: ViewportService { .init(store: viewportStore) }
    var viewportUpdater: ViewportUpdater { .init(viewport: viewportStore, store: viewportUpdateStore) }

    let documentStore = DocumentStore()
    var document: DocumentService { .init(store: documentStore) }

    let pathStore = PathStore()
    let pendingPathStore = PendingPathStore()
    var path: PathService { .init(store: pathStore, pendingStore: pendingPathStore) }

    let activePathStore = ActivePathStore()
    var activePath: ActivePathService { .init(pathStore: pathStore, pendingPathStore: pendingPathStore, store: activePathStore) }

    let pathUpdateStore = PathUpdateStore()
    var pathUpdater: PathUpdater { .init(pathStore: pathStore, pendingPathStore: pendingPathStore, activePathService: activePath, store: pathUpdateStore) }
    var pathUpdaterInView: PathUpdaterInView { .init(viewport: viewport, pathUpdater: pathUpdater) }

    let toolbar = ToolbarStore()

    let selection = SelectionStore()
    let pendingSelectionStore = PendingSelectionStore()
    var pendingSelection: PendingSelectionService { .init(pathStore: pathStore, viewport: viewport, store: pendingSelectionStore) }

    let addingPathStore = AddingPathStore()
    var addingPath: AddingPathService { .init(toolbar: toolbar, viewport: viewport, store: addingPathStore) }
}

let global = GlobalStore()
