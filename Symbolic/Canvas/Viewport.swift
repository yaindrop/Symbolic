//
//  Viewport.swift
//  Symbolic
//
//  Created by Yaindrop on 2024/4/10.
//

import Combine
import Foundation

struct ViewportInfo {
    var origin: CGPoint = CGPoint.zero // top left corner
    var scale: CGFloat = 1.0

    var worldToView: CGAffineTransform { CGAffineTransform(translation: -CGVector(from: origin) * scale).scaledBy(scale: scale) }
    var viewToWorld: CGAffineTransform { worldToView.inverted() }

    func worldRect(viewSize: CGSize) -> CGRect { CGRect(x: origin.x, y: origin.y, width: viewSize.width / scale, height: viewSize.height / scale) }
}

class Viewport: ObservableObject {
    @Published var previousInfo: ViewportInfo = ViewportInfo()
    @Published var info: ViewportInfo = ViewportInfo()

    init(context: MultipleTouchContext) {
        self.context = context
        context.$panInfo.sink { value in
            guard let info = value else { self.onCommit(); return }
            self.onPanInfo(info)
        }.store(in: &subscriptions)
        context.$pinchInfo.sink { value in
            guard let info = value else { self.onCommit(); return }
            self.onPinchInfo(info)
        }.store(in: &subscriptions)
    }

    // MARK: private

    private let context: MultipleTouchContext
    private var subscriptions = Set<AnyCancellable>()

    private func onPanInfo(_ pan: PanInfo) {
        let scale = previousInfo.scale
        let newOrigin = previousInfo.origin - pan.offset / scale
        info = ViewportInfo(origin: newOrigin, scale: scale)
    }

    private func onPinchInfo(_ pinch: PinchInfo) {
        let pinchTransformInView = CGAffineTransform(translation: pinch.center.offset).scaledBy(scale: pinch.scale, around: pinch.center.origin)
        let previousOriginInView = CGPoint.zero.applying(pinchTransformInView)
        let newScale = previousInfo.scale * pinch.scale
        let newOrigin = previousInfo.origin - CGVector(from: previousOriginInView) / newScale
        info = ViewportInfo(origin: newOrigin, scale: newScale)
    }

    private func onCommit() {
        previousInfo = info
    }
}
