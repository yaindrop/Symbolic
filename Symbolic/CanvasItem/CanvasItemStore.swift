import Foundation

typealias CanvasItemMap = OrderedMap<UUID, CanvasItem>

class CanvasItemStore: Store {
    @Trackable var itemMap = CanvasItemMap()
}
