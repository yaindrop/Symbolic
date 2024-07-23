import Foundation

// MARK: - GlobalStores

struct GlobalStores {
    let root = RootStore()

    let fileBrowser = FileBrowserStore()

    let panel = PanelStore()

    let portal = PortalStore()

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
    var viewportUpdater: ViewportUpdater { .init(store: viewportUpdateStore, viewport: viewport, panel: panel) }

    var document: DocumentService { .init(store: documentStore) }
    var documentUpdater: DocumentUpdater { .init(store: documentUpdaterStore, pathStore: pathStore, itemStore: itemStore, pathPropertyStore: pathPropertyStore, activeItem: activeItem, viewport: viewport, grid: grid) }

    var path: PathService { .init(store: pathStore, pendingStore: pendingPathStore, viewport: viewport) }

    var pathProperty: PathPropertyService { .init(store: pathPropertyStore, pendingStore: pendingPathPropertyStore, path: path) }

    var item: ItemService { .init(store: itemStore, pendingStore: pendingItemStore, path: path) }

    var activeItem: ActiveItemService { .init(store: activeItemStore, toolbar: toolbar, item: item, path: path, pathProperty: pathProperty) }

    var focusedPath: FocusedPathService { .init(store: focusedPathStore, activeItem: activeItem) }

    var draggingSelection: DraggingSelectionService { .init(store: draggingSelectionStore, viewport: viewport, item: item, path: path) }

    var addingPath: AddingPathService { .init(store: addingPathStore, viewport: viewport, grid: grid) }
}

let global = GlobalStores()
