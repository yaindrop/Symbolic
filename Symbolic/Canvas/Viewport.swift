//
//  Viewport.swift
//  Symbolic
//
//  Created by Yaindrop on 2024/4/10.
//

import Combine
import Foundation

struct ViewportInfo: CustomStringConvertible {
    var origin: CGPoint = CGPoint.zero // world position of the view origin (top left corner)
    var scale: CGFloat = 1.0

    var worldToView: CGAffineTransform { CGAffineTransform(translation: -CGVector(from: origin) * scale).scaledBy(scale: scale) }
    var viewToWorld: CGAffineTransform { worldToView.inverted() }

    func worldRect(viewSize: CGSize) -> CGRect { CGRect(x: origin.x, y: origin.y, width: viewSize.width / scale, height: viewSize.height / scale) }

    public var description: String { return "ViewportInfo(\(origin.shortDescription), \(scale.shortDescription))" }
}

class Viewport: ObservableObject {
    @Published var info: ViewportInfo = ViewportInfo()
}

// MARK: ViewportUpdater

class ViewportUpdater: ObservableObject {
    @Published var previousInfo: ViewportInfo = ViewportInfo()

    init(viewport: Viewport, touchContext: MultipleTouchContext) {
        self.viewport = viewport
        touchContext.$panInfo.sink { value in
            guard let info = value else { self.onCommit(); return }
            self.onPanInfo(info)
        }.store(in: &subscriptions)
        touchContext.$pinchInfo.sink { value in
            guard let info = value else { self.onCommit(); return }
            self.onPinchInfo(info)
        }.store(in: &subscriptions)
    }

    // MARK: private

    private let viewport: Viewport
    private var subscriptions = Set<AnyCancellable>()

    private func onPanInfo(_ pan: PanInfo) {
        let scale = previousInfo.scale
        let newOrigin = previousInfo.origin - pan.offset / scale
        viewport.info = ViewportInfo(origin: newOrigin, scale: scale)
    }

    private func onPinchInfo(_ pinch: PinchInfo) {
        let pinchTransformInView = CGAffineTransform(translation: pinch.center.offset).scaledBy(scale: pinch.scale, around: pinch.center.origin)
        let previousOriginInView = CGPoint.zero.applying(pinchTransformInView)
        let newScale = previousInfo.scale * pinch.scale
        let newOrigin = previousInfo.origin - CGVector(from: previousOriginInView) / newScale
        viewport.info = ViewportInfo(origin: newOrigin, scale: newScale)
    }

    private func onCommit() {
        previousInfo = viewport.info
    }
}
