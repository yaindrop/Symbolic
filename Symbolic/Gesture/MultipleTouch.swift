import SwiftUI
import UIKit

// MARK: - MultipleTouchModifier

struct MultipleTouchModifier: ViewModifier {
    @ObservedObject var context: MultipleTouchContext

    func body(content: Content) -> some View {
        content.overlay { Representable(context: context) }
    }

    // MARK: private

    private struct Representable: UIViewRepresentable {
        @ObservedObject var context: MultipleTouchContext

        func makeUIView(context: Context) -> UIView { MultipleTouchView(context: self.context) }

        func updateUIView(_ uiView: UIView, context: Context) {}
    }
}

// MARK: - PanInfo

struct PanInfo {
    let origin: Point2
    let offset: Vector2

    var current: Point2 { origin + offset }

    init(origin: Point2, offset: Vector2 = Vector2.zero) {
        self.origin = origin
        self.offset = offset
    }
}

extension PanInfo: CustomStringConvertible {
    public var description: String { "(\(origin.shortDescription), \(offset.shortDescription)" }
}

// MARK: - PinchInfo

struct PinchInfo {
    let origin: (Point2, Point2)
    let offset: (Vector2, Vector2)

    var current: (Point2, Point2) { (origin.0 + offset.0, origin.1 + offset.1) }

    var center: PanInfo {
        let (o0, o1) = origin
        let originMid = o0.midPoint(to: o1)
        let (c0, c1) = current
        let currentMid = c0.midPoint(to: c1)
        return .init(origin: originMid, offset: originMid.offset(to: currentMid))
    }

    var originDistance: Scalar {
        let (o0, o1) = origin
        return o0.distance(to: o1)
    }

    var currentDistance: Scalar {
        let (c0, c1) = current
        return c0.distance(to: c1)
    }

    var scale: Scalar { currentDistance / originDistance }

    init(origin: (Point2, Point2), offset: (Vector2, Vector2) = (Vector2.zero, Vector2.zero)) {
        self.origin = origin
        self.offset = offset
    }
}

extension PinchInfo: CustomStringConvertible {
    public var description: String {
        "((\(origin.0.shortDescription), \(origin.1.shortDescription)), (\(offset.0.shortDescription), \(offset.1.shortDescription)))"
    }
}

// MARK: - MultipleTouchContext

class MultipleTouchContext: ObservableObject {
    @Published private(set) var startTime: Date?

    @Published var touchesCount: Int = 0
    @Published var panInfo: PanInfo?
    @Published var pinchInfo: PinchInfo?

    var active: Bool { startTime != nil }

    fileprivate func onFirstTouchBegan() {
        startTime = .now
    }

    fileprivate func onAllTouchesEnded() {
        startTime = nil
        touchesCount = 0
        panInfo = nil
        pinchInfo = nil
    }
}

// MARK: - MultipleTouchView

class MultipleTouchView: TouchDebugView {
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
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
        super.touchesEnded(touches, with: event)
        activeTouches.subtract(touches)
        if activeTouches.isEmpty {
            context.onAllTouchesEnded()
        } else {
            onActiveTouchesChanged()
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        activeTouches.subtract(touches)
        if activeTouches.isEmpty {
            context.onAllTouchesEnded()
        } else {
            onActiveTouchesChanged()
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        onActiveTouchesMoved()
    }

    init(context: MultipleTouchContext, frame: CGRect) {
        self.context = context
        super.init(frame: frame)
        isMultipleTouchEnabled = true
    }

    convenience init(context: MultipleTouchContext) {
        self.init(context: context, frame: CGRect.zero)
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("This class does not support NSCoding")
    }

    // MARK: private

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

    private func location(of touch: UITouch) -> Point2 { touch.location(in: self) }

    private func onActiveTouchesChanged() {
        context.touchesCount = activeTouches.count
        context.panInfo = nil
        context.pinchInfo = nil
        if let panTouch {
            context.panInfo = PanInfo(origin: location(of: panTouch))
        } else if let pinchTouches {
            context.pinchInfo = PinchInfo(origin: (location(of: pinchTouches.0), location(of: pinchTouches.1)))
        }
    }

    private func onActiveTouchesMoved() {
        if let info = context.panInfo, let panTouch {
            context.panInfo = .init(origin: info.origin, offset: Vector2(location(of: panTouch)) - Vector2(info.origin))
        } else if let info = context.pinchInfo, let pinchTouches {
            context.pinchInfo = .init(
                origin: info.origin,
                offset: (Vector2(location(of: pinchTouches.0)) - Vector2(info.origin.0), Vector2(location(of: pinchTouches.1)) - Vector2(info.origin.1))
            )
        }
    }
}
