import Foundation

// MARK: - GlobalStores

struct GlobalStores {
    let root = RootStore()

    let fileBrowser = FileBrowserStore()

    let panel = PanelStore()

    let toolbar = ToolbarStore()

    let canvasAction = CanvasActionStore()

    let grid = GridStore()

    let contextMenu = ContextMenuStore()

    private let viewportStore = ViewportStore()
    private let viewportUpdateStore = ViewportUpdateStore()

    private let documentStore = DocumentStore()
    private let documentUpdaterStore = DocumentUpdaterStore()

    private let pathStore = PathStore()
    private let pendingPathStore = PendingPathStore()

    private let pathPropertyStore = PathPropertyStore()
    private let pendingPathPropertyStore = PendingPathPropertyStore()

    private let itemStore = ItemStore()
    private let pendingItemStore = PendingItemStore()

    private let activeItemStore = ActiveItemStore()

    private let focusedPathStore = FocusedPathStore()

    private let draggingSelectionStore = DraggingSelectionStore()

    private let addingPathStore = AddingPathStore()
}

// MARK: services

extension GlobalStores {
    var viewport: ViewportService { .init(store: viewportStore) }
    var viewportUpdater: ViewportUpdater { .init(viewport: viewportStore, store: viewportUpdateStore) }

    var document: DocumentService { .init(store: documentStore) }
    var documentUpdater: DocumentUpdater { .init(pathStore: pathStore, itemStore: itemStore, pathPropertyStore: pathPropertyStore, activeItem: activeItem, viewport: viewport, grid: grid, store: documentUpdaterStore) }

    var path: PathService { .init(viewport: viewport, store: pathStore, pendingStore: pendingPathStore) }

    var pathProperty: PathPropertyService { .init(path: path, store: pathPropertyStore, pendingStore: pendingPathPropertyStore) }

    var item: ItemService { .init(path: path, store: itemStore, pendingStore: pendingItemStore) }

    var activeItem: ActiveItemService { .init(viewport: viewport, toolbar: toolbar, item: item, path: path, pathProperty: pathProperty, store: activeItemStore) }

    var focusedPath: FocusedPathService { .init(viewport: viewport, activeItem: activeItem, store: focusedPathStore) }

    var draggingSelection: DraggingSelectionService { .init(viewport: viewport, store: draggingSelectionStore) }

    var addingPath: AddingPathService { .init(viewport: viewport, grid: grid, store: addingPathStore) }
}

let global = GlobalStores()
