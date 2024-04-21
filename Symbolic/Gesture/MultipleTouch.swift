//
//  MultipleTouch.swift
//  Symbolic
//
//  Created by Yaindrop on 2024/4/10.
//

import SwiftUI
import UIKit

// MARK: MultipleTouchModifier

struct MultipleTouchModifier: ViewModifier {
    private struct Representable: UIViewRepresentable {
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
        return content.overlay { Representable(context: context) }
    }
}

// MARK: multiple touch info

struct PanInfo {
    var origin: CGPoint
    var offset: CGVector = CGVector.zero

    var current: CGPoint {
        return origin + offset
    }

    public var description: String { return "PanInfo(\(origin.shortDescription), \(offset.shortDescription))" }
}

struct PinchInfo {
    var origin: (CGPoint, CGPoint)
    var offset: (CGVector, CGVector) = (CGVector.zero, CGVector.zero)

    var current: (CGPoint, CGPoint) {
        return (origin.0 + offset.0, origin.1 + offset.1)
    }

    var center: PanInfo {
        let originVector = (CGVector(origin.0) + CGVector(origin.1)) / 2
        let current = self.current
        let currentVector = (CGVector(current.0) + CGVector(current.1)) / 2
        return PanInfo(origin: CGPoint(originVector), offset: currentVector - originVector)
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

    public var description: String { return "PinchInfo((\(origin.0.shortDescription), \(origin.1.shortDescription)), (\(offset.0.shortDescription), \(offset.1.shortDescription)))" }
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
            state = .began
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
            state = .ended
        } else {
            onActiveTouchesChanged()
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        activeTouches.subtract(touches)
        if activeTouches.isEmpty {
            context.onAllTouchesEnded()
            state = .cancelled
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
            let movedInfo = PanInfo(origin: info.origin, offset: CGVector(location(of: touch)) - CGVector(info.origin))
            context.maxPanOffset = max(context.maxPanOffset, movedInfo.offset.length())
            context.panInfo = movedInfo
        } else if let info = context.pinchInfo, let touches = pinchTouches {
            let movedInfo = PinchInfo(origin: info.origin, offset: (CGVector(location(of: touches.0)) - CGVector(info.origin.0), CGVector(location(of: touches.1)) - CGVector(info.origin.1)))
            context.pinchInfo = movedInfo
        }
    }
}
