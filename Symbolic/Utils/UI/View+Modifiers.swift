import Foundation
import SwiftUI

// MARK: - viewSizeReader

extension View {
    func geometryReader(onSize: ((CGSize) -> Void)? = nil, onGeometry: ((GeometryProxy) -> Void)? = nil) -> some View {
        background {
            GeometryReader { geometry in
                Color.clear
                    .onChange(of: geometry.frame(in: .global), initial: true) {
                        onSize?(geometry.size)
                        onGeometry?(geometry)
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
