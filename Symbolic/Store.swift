import Foundation

class GlobalStore {
    let viewportModel = ViewportModel()
    let viewportUpdateModel = ViewportUpdateModel()

    let documentModel = DocumentModel()

    let pathModel = PathModel()
    let pendingPathModel = PendingPathModel()

    let activePathModel = ActivePathModel()

    let pathUpdateModel = PathUpdateModel()
}

let store = GlobalStore()

let viewportUpdater = ViewportUpdater(viewport: store.viewportModel, model: store.viewportUpdateModel)
let pathInteractor = PathInteractor(model: store.pathModel, pendingModel: store.pendingPathModel)
let activePathInteractor = ActivePathInteractor(pathModel: store.pathModel, pendingPathModel: store.pendingPathModel, model: store.activePathModel)
let pathUpdater = PathUpdater(pathModel: store.pathModel, pendingPathModel: store.pendingPathModel, activePathModel: store.activePathModel, model: store.pathUpdateModel)
let pathUpdaterInView = PathUpdaterInView(viewport: store.viewportModel, pathModel: store.pathModel, pendingPathModel: store.pendingPathModel, activePathModel: store.activePathModel, pathUpdateModel: store.pathUpdateModel)
