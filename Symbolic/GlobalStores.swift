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

    private let itemStore = ItemStore()
    private let pendingItemStore = PendingItemStore()

    private let pathStore = PathStore()
    private let pendingPathStore = PendingPathStore()

    private let pathPropertyStore = PathPropertyStore()
    private let pendingPathPropertyStore = PendingPathPropertyStore()

    private let activeSymbolStore = ActiveSymbolStore()

    private let activeItemStore = ActiveItemStore()

    private let focusedPathStore = FocusedPathStore()

    private let draggingSelectStore = DraggingSelectStore()

    private let draggingCreateStore = DraggingCreateStore()
}

// MARK: services

extension GlobalStores {
    var viewport: ViewportService { .init(store: viewportStore) }
    var viewportUpdater: ViewportUpdater { .init(store: viewportUpdateStore, viewport: viewport, panel: panel) }

    var document: DocumentService { .init(store: documentStore) }
    var documentUpdater: DocumentUpdater { .init(store: documentUpdaterStore, pathStore: pathStore, pathPropertyStore: pathPropertyStore, itemStore: itemStore, activeItem: activeItem, viewport: viewport, grid: grid) }

    var path: PathService { .init(store: pathStore, pendingStore: pendingPathStore) }

    var pathProperty: PathPropertyService { .init(store: pathPropertyStore, pendingStore: pendingPathPropertyStore, path: path) }

    var item: ItemService { .init(store: itemStore, pendingStore: pendingItemStore, viewport: viewport, path: path) }

    var activeSymbol: ActiveSymbolService { .init(store: activeSymbolStore, item: item) }

    var activeItem: ActiveItemService { .init(store: activeItemStore, toolbar: toolbar, item: item, path: path, pathProperty: pathProperty) }

    var focusedPath: FocusedPathService { .init(store: focusedPathStore, activeItem: activeItem) }

    var draggingSelect: DraggingSelectService { .init(store: draggingSelectStore, viewport: viewport, activeSymbol: activeSymbol, path: path, item: item) }

    var draggingCreate: DraggingCreateService { .init(store: draggingCreateStore, viewport: viewport, activeSymbol: activeSymbol, activeItem: activeItem, documentUpdater: documentUpdater, canvasAction: canvasAction) }
}

let global = GlobalStores()
