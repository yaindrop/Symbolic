import Foundation

typealias CanvasGroupMap = [UUID: CanvasGroup]

class CanvasGroupStore: Store {
    @Trackable var groupMap = CanvasGroupMap()
}
