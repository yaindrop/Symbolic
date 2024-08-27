import Foundation

// MARK: - GlobalStores

struct GlobalStores {
    let root = RootStore()

    let fileBrowser = FileBrowserStore()

    private let documentStore = DocumentStore()
    private let documentUpdaterStore = DocumentUpdaterStore()

    private let pathStore = PathStore()
    private let pendingPathStore = PendingPathStore()

    private let pathPropertyStore = PathPropertyStore()
    private let pendingPathPropertyStore = PendingPathPropertyStore()

    private let itemStore = ItemStore()
    private let pendingItemStore = PendingItemStore()

    private let viewportStore = ViewportStore()
    private let viewportUpdateStore = ViewportUpdateStore()

    private let activeSymbolStore = ActiveSymbolStore()

    private let activeItemStore = ActiveItemStore()

    private let focusedPathStore = FocusedPathStore()

    private let draggingSelectStore = DraggingSelectStore()

    private let draggingCreateStore = DraggingCreateStore()

    let grid = GridStore()

    let panel = PanelStore()

    let portal = PortalStore()

    let toolbar = ToolbarStore()

    let canvasAction = CanvasActionStore()

    let contextMenu = ContextMenuStore()
}

// MARK: services

extension GlobalStores {
    var document: DocumentService { .init(store: documentStore) }
    var documentUpdater: DocumentUpdater { .init(store: documentUpdaterStore, pathStore: pathStore, pathPropertyStore: pathPropertyStore, itemStore: itemStore, viewport: viewport, activeItem: activeItem, grid: grid) }

    var path: PathService { .init(store: pathStore, pendingStore: pendingPathStore) }

    var pathProperty: PathPropertyService { .init(store: pathPropertyStore, pendingStore: pendingPathPropertyStore, path: path) }

    var item: ItemService { .init(store: itemStore, pendingStore: pendingItemStore, path: path, viewport: viewport) }

    var viewport: ViewportService { .init(store: viewportStore) }
    var viewportUpdater: ViewportUpdater { .init(store: viewportUpdateStore, viewport: viewport, panel: panel) }

    var activeSymbol: ActiveSymbolService { .init(store: activeSymbolStore, path: path, item: item, viewport: viewport) }

    var activeItem: ActiveItemService { .init(store: activeItemStore, toolbar: toolbar, path: path, pathProperty: pathProperty, item: item) }

    var focusedPath: FocusedPathService { .init(store: focusedPathStore, activeItem: activeItem) }

    var draggingSelect: DraggingSelectService { .init(store: draggingSelectStore, path: path, item: item, viewport: viewport, activeSymbol: activeSymbol) }

    var draggingCreate: DraggingCreateService { .init(store: draggingCreateStore, viewport: viewport, activeSymbol: activeSymbol) }
}

let global = GlobalStores()
