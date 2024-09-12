import Foundation

// MARK: - GlobalStores

struct GlobalStores {
    let root = RootStore()

    let fileBrowser = FileBrowserStore()

    private let documentStore = DocumentStore()
    private let documentUpdaterStore = DocumentUpdaterStore()

    private let pathStore = PathStore()
    private let pendingPathStore = PendingPathStore()

    private let symbolStore = SymbolStore()
    private let pendingSymbolStore = PendingSymbolStore()

    private let itemStore = ItemStore()
    private let pendingItemStore = PendingItemStore()

    private let activeSymbolStore = ActiveSymbolStore()

    private let activeItemStore = ActiveItemStore()

    private let focusedPathStore = FocusedPathStore()

    private let viewportStore = ViewportStore()
    private let viewportUpdateStore = ViewportUpdateStore()

    private let draggingSelectStore = DraggingSelectStore()

    private let draggingCreateStore = DraggingCreateStore()

    let panel = PanelStore()

    let portal = PortalStore()

    let toolbar = ToolbarStore()

    let canvasAction = CanvasActionStore()

    let contextMenu = ContextMenuStore()
}

// MARK: services

extension GlobalStores {
    var document: DocumentService { .init(store: documentStore) }
    var documentUpdater: DocumentUpdater { .init(store: documentUpdaterStore, pathStore: pathStore, symbolStore: symbolStore, itemStore: itemStore, viewport: viewport, activeSymbol: activeSymbol, activeItem: activeItem) }

    var path: PathService { .init(store: pathStore, pendingStore: pendingPathStore) }

    var symbol: SymbolService { .init(store: symbolStore, pendingStore: pendingSymbolStore) }

    var item: ItemService { .init(store: itemStore, pendingStore: pendingItemStore, path: path, viewport: viewport) }

    var focusedPath: FocusedPathService { .init(store: focusedPathStore, item: item, activeItem: activeItem) }

    var activeSymbol: ActiveSymbolService { .init(store: activeSymbolStore, path: path, symbol: symbol, item: item, viewport: viewport) }

    var activeItem: ActiveItemService { .init(store: activeItemStore, toolbar: toolbar, path: path, item: item) }

    var viewport: ViewportService { .init(store: viewportStore) }
    var viewportUpdater: ViewportUpdater { .init(store: viewportUpdateStore, viewport: viewport, activeSymbol: activeSymbol, panel: panel) }

    var draggingSelect: DraggingSelectService { .init(store: draggingSelectStore, path: path, symbol: symbol, item: item, viewport: viewport, activeSymbol: activeSymbol) }

    var draggingCreate: DraggingCreateService { .init(store: draggingCreateStore, viewport: viewport, activeSymbol: activeSymbol) }
}

let global = GlobalStores()
