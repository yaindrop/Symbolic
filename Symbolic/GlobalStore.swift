import Foundation

struct GlobalStore {
    private let viewportStore = ViewportStore()
    private let viewportUpdateStore = ViewportUpdateStore()
    var viewport: ViewportService { .init(store: viewportStore) }
    var viewportUpdater: ViewportUpdater { .init(viewport: viewportStore, store: viewportUpdateStore) }

    private let documentStore = DocumentStore()
    var document: DocumentService { .init(store: documentStore) }

    private let documentUpdaterStore = DocumentUpdaterStore()
    var documentUpdater: DocumentUpdater { .init(pathStore: pathStore, itemStore: itemStore, activeItem: activeItem, viewport: viewport, grid: grid, store: documentUpdaterStore) }

    private let pathStore = PathStore()
    private let pendingPathStore = PendingPathStore()
    var path: PathService { .init(viewport: viewport, store: pathStore, pendingStore: pendingPathStore) }

    private let itemStore = ItemStore()
    private let pendingItemStore = PendingItemStore()
    var item: ItemService { .init(path: path, store: itemStore, pendingStore: pendingItemStore) }

    private let activeItemStore = ActiveItemStore()
    var activeItem: ActiveItemService { .init(item: item, path: path, store: activeItemStore) }

    let toolbar = ToolbarStore()

    private let draggingSelectionStore = DraggingSelectionStore()
    var draggingSelection: DraggingSelectionService { .init(pathStore: pathStore, viewport: viewport, store: draggingSelectionStore) }

    private let addingPathStore = AddingPathStore()
    var addingPath: AddingPathService { .init(toolbar: toolbar, viewport: viewport, grid: grid, store: addingPathStore) }

    let canvasAction = CanvasActionStore()

    let grid = GridStore()
    let contextMenu = ContextMenuStore()
}

let global = GlobalStore()
