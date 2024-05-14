import Foundation

class GlobalStore {
    let viewport = ViewportModel()
    let viewportUpdate = ViewportUpdateModel()

    let document = DocumentModel()

    let path = PathModel()
    let pendingPath = PendingPathModel()

    let activePath = ActivePathModel()

    let pathUpdate = PathUpdateModel()
}

let store = GlobalStore()

class GlobalInteractor {
    let viewportUpdater = ViewportUpdater(viewport: store.viewport, model: store.viewportUpdate)

    let path = PathInteractor(model: store.path, pendingModel: store.pendingPath)
    let activePath = ActivePathInteractor(pathModel: store.path, pendingPathModel: store.pendingPath, model: store.activePath)

    let pathUpdater = PathUpdater(pathModel: store.path, pendingPathModel: store.pendingPath, activePathModel: store.activePath, model: store.pathUpdate)
    let pathUpdaterInView = PathUpdaterInView(viewport: store.viewport, pathModel: store.path, pendingPathModel: store.pendingPath, activePathModel: store.activePath, pathUpdateModel: store.pathUpdate)
}

let interactor = GlobalInteractor()
