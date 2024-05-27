import Foundation
import SwiftUI

public extension Gesture {
    @inlinable func updating(flag: GestureState<Bool>) -> GestureStateGesture<Self, Bool> {
        updating(flag) { _, state, _ in state = true }
    }
}

extension DragGesture.Value {
    var offset: Vector2 { .init(translation) }

    var speed: Vector2 { .init(velocity) }
}
