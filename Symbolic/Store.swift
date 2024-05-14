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
