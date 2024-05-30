import Foundation
import SwiftUI

// MARK: - viewSizeReader

extension View {
    func viewSizeReader(onSize: @escaping (CGSize) -> Void) -> some View {
        background {
            GeometryReader { geometry in
                Color.clear
                    .onChange(of: geometry.size, initial: true) {
                        onSize(geometry.size)
                    }
            }
        }
    }
}

// MARK: - framePosition

extension View {
    func framePosition(rect: CGRect) -> some View {
        frame(width: rect.width, height: rect.height)
            .position(rect.center)
    }
}
