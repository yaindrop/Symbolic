import Foundation

struct GlobalStore {
    private let viewportStore = ViewportStore()
    private let viewportUpdateStore = ViewportUpdateStore()
    var viewport: ViewportService { .init(store: viewportStore) }
    var viewportUpdater: ViewportUpdater { .init(viewport: viewportStore, store: viewportUpdateStore) }

    private let documentStore = DocumentStore()
    var document: DocumentService { .init(store: documentStore) }

    private let pathStore = PathStore()
    private let pendingPathStore = PendingPathStore()
    var path: PathService { .init(store: pathStore, pendingStore: pendingPathStore) }

    private let activePathStore = ActivePathStore()
    var activePath: ActivePathService { .init(pathStore: pathStore, pendingPathStore: pendingPathStore, store: activePathStore) }

    private let pathUpdateStore = PathUpdateStore()
    var pathUpdater: PathUpdater { .init(pathStore: pathStore, pendingPathStore: pendingPathStore, activePath: activePath, viewport: viewport, grid: canvasGrid, store: pathUpdateStore) }

    let toolbar = ToolbarStore()

    let selection = SelectionStore()

    private let pendingSelectionStore = PendingSelectionStore()
    var pendingSelection: PendingSelectionService { .init(pathStore: pathStore, viewport: viewport, store: pendingSelectionStore) }

    private let addingPathStore = AddingPathStore()
    var addingPath: AddingPathService { .init(toolbar: toolbar, viewport: viewport, grid: canvasGrid, store: addingPathStore) }

    let canvasAction = CanvasActionStore()

    let canvasGrid = CanvasGridStore()

    let canvasItemStore = CanvasItemStore()
    let pendingCanvasItemStore = PendingCanvasItemStore()
    var canvasItem: CanvasItemService { .init(pathService: path, store: canvasItemStore, pendingStore: pendingCanvasItemStore) }
}

let global = GlobalStore()
