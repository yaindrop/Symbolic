//
//  Viewport.swift
//  Symbolic
//
//  Created by Yaindrop on 2024/4/10.
//

import Foundation

struct ViewportInfo {
    var center: CGPoint = CGPoint.zero
    var scale: CGFloat = 1.0

    func getWorldRect(viewRect: CGRect) -> CGRect {
        let width = viewRect.width / scale
        let height = viewRect.height / scale
        return CGRect(x: center.x - width / 2, y: center.y - height / 2, width: width, height: height)
    }

    func getWorldToView(viewRect: CGRect) -> CGAffineTransform {
        let worldRect = getWorldRect(viewRect: viewRect)
        let offset = center.deltaVector(to: viewRect.center)
        return CGAffineTransform(translation: offset).scaledBy(xy: scale)
    }
}

class ViewportUpdater: ObservableObject {
    @State var info: ViewportInfo = ViewportInfo()

    init(context: MultipleTouchContext) {
        self.context = context
    }

    // MARK: private

    private let context: MultipleTouchContext
    private var subscriptions = Set<AnyCancellable>()
}
