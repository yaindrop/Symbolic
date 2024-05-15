import Foundation
import SwiftUI

struct ViewSizeReader: ViewModifier {
    var onSize: (CGSize) -> Void

    func body(content: Content) -> some View {
        content.background {
            GeometryReader { geometry in
                Color.clear
                    .onChange(of: geometry.size, initial: true) {
                        onSize(geometry.size)
                    }
            }
        }
    }
}

extension View {
    func viewSizeReader(onSize: @escaping (CGSize) -> Void) -> some View {
        modifier(ViewSizeReader(onSize: onSize))
    }
}
