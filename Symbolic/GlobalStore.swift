import Foundation

struct GlobalStore {
    private let viewportStore = ViewportStore()
    private let viewportUpdateStore = ViewportUpdateStore()
    var viewport: ViewportService { .init(store: viewportStore) }
    var viewportUpdater: ViewportUpdater { .init(viewport: viewportStore, store: viewportUpdateStore) }

    private let documentStore = DocumentStore()
    var document: DocumentService { .init(store: documentStore) }

    private let documentUpdaterStore = DocumentUpdaterStore()
    var documentUpdater: DocumentUpdater { .init(pathStore: pathStore, pendingPathStore: pendingPathStore, activePath: activePath, viewport: viewport, grid: canvasGrid, store: documentUpdaterStore) }

    private let pathStore = PathStore()
    private let pendingPathStore = PendingPathStore()
    var path: PathService { .init(store: pathStore, pendingStore: pendingPathStore) }

    private let activePathStore = ActivePathStore()
    var activePath: ActivePathService { .init(path: path, store: activePathStore) }

    let toolbar = ToolbarStore()

    let selection = SelectionStore()

    private let pendingSelectionStore = PendingSelectionStore()
    var pendingSelection: PendingSelectionService { .init(pathStore: pathStore, viewport: viewport, store: pendingSelectionStore) }

    private let addingPathStore = AddingPathStore()
    var addingPath: AddingPathService { .init(toolbar: toolbar, viewport: viewport, grid: canvasGrid, store: addingPathStore) }

    let canvasAction = CanvasActionStore()

    let canvasGrid = CanvasGridStore()

    let canvasGroupStore = CanvasGroupStore()
    let pendingCanvasGroupStore = PendingCanvasGroupStore()
    var canvasGroup: CanvasGroupService { .init(store: canvasGroupStore, pendingStore: pendingCanvasGroupStore) }

    let canvasItemStore = CanvasItemStore()
    let pendingCanvasItemStore = PendingCanvasItemStore()
    var canvasItem: CanvasItemService { .init(pathService: path, groupService: canvasGroup, store: canvasItemStore, pendingStore: pendingCanvasItemStore) }
}

let global = GlobalStore()
