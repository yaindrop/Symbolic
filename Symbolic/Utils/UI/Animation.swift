import Foundation
import SwiftUI

struct AnimatedValue<Value: Equatable>: ViewModifier {
    @Binding var value: Value
    let from: Value
    let to: Value
    let animation: Animation

    func body(content: Content) -> some View {
        content
            .animation(animation, value: value)
            .onAppear { value = to }
            .onDisappear { value = from }
    }
}
