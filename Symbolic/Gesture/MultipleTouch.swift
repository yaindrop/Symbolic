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

struct PanInfo: CustomStringConvertible {
    var origin: Point2
    var offset: Vector2 = Vector2.zero

    var current: Point2 {
        return origin + offset
    }

    public var description: String { "(\(origin.shortDescription), \(offset.shortDescription)" }
}

struct PinchInfo: CustomStringConvertible {
    var origin: (Point2, Point2)
    var offset: (Vector2, Vector2) = (Vector2.zero, Vector2.zero)

    var current: (Point2, Point2) {
        return (origin.0 + offset.0, origin.1 + offset.1)
    }

    var center: PanInfo {
        let originVector = (Vector2(origin.0) + Vector2(origin.1)) / 2
        let current = self.current
        let currentVector = (Vector2(current.0) + Vector2(current.1)) / 2
        return PanInfo(origin: Point2(originVector), offset: currentVector - originVector)
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

    public var description: String { return "((\(origin.0.shortDescription), \(origin.1.shortDescription)), (\(offset.0.shortDescription), \(offset.1.shortDescription)))" }
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

    private func location(of touch: UITouch) -> Point2 { touch.location(in: view) }

    private func onActiveTouchesChanged() {
        context.panInfo = nil
        context.pinchInfo = nil
        context.maxTouchesCount = max(context.maxTouchesCount, activeTouches.count)
        if let panTouch {
            context.panInfo = PanInfo(origin: location(of: panTouch))
        } else if let pinchTouches {
            context.pinchInfo = PinchInfo(origin: (location(of: pinchTouches.0), location(of: pinchTouches.1)))
        }
    }

    private func onActiveTouchesMoved() {
        if let info = context.panInfo, let panTouch {
            let movedInfo = PanInfo(origin: info.origin, offset: Vector2(location(of: panTouch)) - Vector2(info.origin))
            context.maxPanOffset = max(context.maxPanOffset, movedInfo.offset.length())
            context.panInfo = movedInfo
        } else if let info = context.pinchInfo, let pinchTouches {
            let movedInfo = PinchInfo(origin: info.origin, offset: (Vector2(location(of: pinchTouches.0)) - Vector2(info.origin.0), Vector2(location(of: pinchTouches.1)) - Vector2(info.origin.1)))
            context.pinchInfo = movedInfo
        }
    }
}
