//
//  MultipleTouch.swift
//  Symbolic
//
//  Created by Yaindrop on 2024/4/10.
//

import SwiftUI
import UIKit

// MARK: MultipleTouchable

struct MultipleTouchable: ViewModifier {
    private struct MultipleTouchRepresentable: UIViewRepresentable {
        @ObservedObject var context: MultipleTouchContext

        func makeUIView(context: Context) -> UIView {
            let view = UIView()
            view.isMultipleTouchEnabled = true
            view.addGestureRecognizer(DebugTouchHandler())
            view.addGestureRecognizer(MultipleTouchHandler(context: self.context))
            return view
        }

        func updateUIView(_ uiView: UIView, context: Context) {}
    }

    @ObservedObject var context: MultipleTouchContext

    func body(content: Content) -> some View {
        return content
            .overlay {
                MultipleTouchRepresentable(context: context)
            }
    }
}

// MARK: multiple touch info

struct PanInfo {
    var origin: CGPoint
    var offset: CGVector = CGVector.zero

    var current: CGPoint {
        return origin + offset
    }
}

struct PinchInfo {
    var origin: (CGPoint, CGPoint)
    var offset: (CGVector, CGVector) = (CGVector.zero, CGVector.zero)

    var current: (CGPoint, CGPoint) {
        return (origin.0 + offset.0, origin.1 + offset.1)
    }

    var center: PanInfo {
        let originVector = (CGVector(from: origin.0) + CGVector(from: origin.1)) / 2
        let current = self.current
        let currentVector = (CGVector(from: current.0) + CGVector(from: current.1)) / 2
        return PanInfo(origin: CGPoint(from: originVector), offset: currentVector - originVector)
    }

    var originDistance: CGFloat {
        origin.0.distance(to: origin.1)
    }

    var currentDistance: CGFloat {
        let current = self.current
        return current.0.distance(to: current.1)
    }

    var scale: CGFloat {
        return currentDistance / originDistance
    }
}

// MARK: MultipleTouchContext

class MultipleTouchContext: ObservableObject {
    @Published var active: Bool = false
    @Published var maxTouchesCount: Int = 0
    @Published var maxPanOffset: CGFloat = 0
    @Published var firstTouchBeganTime: Date?

    @Published var panInfo: PanInfo?
    @Published var pinchInfo: PinchInfo?

    func onFirstTouchBegan() {
        firstTouchBeganTime = Date()
        active = true
    }

    func onAllTouchesEnded() {
        active = false
        maxTouchesCount = 0
        maxPanOffset = 0
        firstTouchBeganTime = nil
        panInfo = nil
        pinchInfo = nil
    }
}

// MARK: MultipleTouchHandler

class MultipleTouchHandler: UIGestureRecognizer, ObservableObject {
    init(context: MultipleTouchContext) {
        self.context = context
        super.init(target: nil, action: nil)
    }

    private var context: MultipleTouchContext

    private var activeTouches = Set<UITouch>()
    private var panTouch: UITouch? { activeTouches.count == 1 ? activeTouches.first : nil }
    private var pinchTouches: (UITouch, UITouch)? {
        if activeTouches.count != 2 {
            return nil
        }
        let touches = Array(activeTouches)
        return (touches[0], touches[1])
    }

    // MARK: event handler

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if activeTouches.isEmpty {
            context.onFirstTouchBegan()
        }
        for touch in touches {
            // only allow 2 touches at most for now
            if activeTouches.count == 2 {
                break
            }
            activeTouches.insert(touch)
        }
        onActiveTouchesChanged()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        activeTouches.subtract(touches)
        if activeTouches.isEmpty {
            context.onAllTouchesEnded()
        } else {
            onActiveTouchesChanged()
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        activeTouches.subtract(touches)
        if activeTouches.isEmpty {
            context.onAllTouchesEnded()
        } else {
            onActiveTouchesChanged()
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        onActiveTouchesMoved()
    }

    // MARK: calc info

    private func location(of touch: UITouch) -> CGPoint { touch.location(in: view) }

    private func onActiveTouchesChanged() {
        context.panInfo = nil
        context.pinchInfo = nil
        context.maxTouchesCount = max(context.maxTouchesCount, activeTouches.count)
        if let touch = panTouch {
            context.panInfo = PanInfo(origin: location(of: touch))
        } else if let touches = pinchTouches {
            context.pinchInfo = PinchInfo(origin: (location(of: touches.0), location(of: touches.1)))
        }
    }

    private func onActiveTouchesMoved() {
        if let info = context.panInfo, let touch = panTouch {
            let movedInfo = PanInfo(origin: info.origin, offset: CGVector(from: location(of: touch)) - CGVector(from: info.origin))
            context.maxPanOffset = max(context.maxPanOffset, movedInfo.offset.length())
            context.panInfo = movedInfo
        } else if let info = context.pinchInfo, let touches = pinchTouches {
            let movedInfo = PinchInfo(origin: info.origin, offset: (CGVector(from: location(of: touches.0)) - CGVector(from: info.origin.0), CGVector(from: location(of: touches.1)) - CGVector(from: info.origin.1)))
            context.pinchInfo = movedInfo
        }
    }
}
