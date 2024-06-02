import Foundation

// MARK: - GlobalStore

struct GlobalStore {
    private let viewportStore = ViewportStore()
    private let viewportUpdateStore = ViewportUpdateStore()

    private let documentStore = DocumentStore()
    private let documentUpdaterStore = DocumentUpdaterStore()

    private let pathStore = PathStore()
    private let pendingPathStore = PendingPathStore()

    private let itemStore = ItemStore()
    private let pendingItemStore = PendingItemStore()

    private let activeItemStore = ActiveItemStore()

    private let draggingSelectionStore = DraggingSelectionStore()

    private let addingPathStore = AddingPathStore()

    let panel = PanelStore()

    let toolbar = ToolbarStore()

    let canvasAction = CanvasActionStore()

    let grid = GridStore()

    let contextMenu = ContextMenuStore()
}

// MARK: services

extension GlobalStore {
    var viewport: ViewportService { .init(store: viewportStore) }
    var viewportUpdater: ViewportUpdater { .init(viewport: viewportStore, store: viewportUpdateStore) }

    var document: DocumentService { .init(store: documentStore) }
    var documentUpdater: DocumentUpdater { .init(pathStore: pathStore, itemStore: itemStore, activeItem: activeItem, viewport: viewport, grid: grid, store: documentUpdaterStore) }

    var path: PathService { .init(viewport: viewport, store: pathStore, pendingStore: pendingPathStore) }

    var item: ItemService { .init(path: path, store: itemStore, pendingStore: pendingItemStore) }

    var activeItem: ActiveItemService { .init(viewport: viewport, toolbar: toolbar, item: item, path: path, store: activeItemStore) }

    var draggingSelection: DraggingSelectionService { .init(viewport: viewport, store: draggingSelectionStore) }

    var addingPath: AddingPathService { .init(viewport: viewport, grid: grid, store: addingPathStore) }
}

let global = GlobalStore()
