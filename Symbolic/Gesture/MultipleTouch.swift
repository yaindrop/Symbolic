import Combine
import SwiftUI
import UIKit

// MARK: - PanInfo

struct PanInfo: Equatable {
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

struct PinchInfo: EquatableBy {
    let origin: (Point2, Point2)
    let offset: (Vector2, Vector2)

    var equatableBy: some Equatable { EquatableTuple.init <- origin; EquatableTuple.init <- offset }

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

// MARK: - MultipleTouchModel

@Observable
class MultipleTouchModel {
    private(set) var startTime: Date?

    private(set) var touchesCount: Int = 0
    private(set) var panInfo: PanInfo?
    private(set) var pinchInfo: PinchInfo?

    @ObservationIgnored let startTimeSubject = PassthroughSubject<Date?, Never>()

    @ObservationIgnored let touchesCountSubject = PassthroughSubject<Int?, Never>()
    @ObservationIgnored let panInfoSubject = PassthroughSubject<PanInfo?, Never>()
    @ObservationIgnored let pinchInfoSubject = PassthroughSubject<PinchInfo?, Never>()

    var active: Bool { startTime != nil }

    fileprivate func onTouchesCount(_ count: Int) {
        guard touchesCount != count else { return }
        touchesCountSubject.send(count)
        touchesCount = count
    }

    fileprivate func onPanInfo(_ info: PanInfo?) {
        guard panInfo != info else { return }
        panInfoSubject.send(info)
        panInfo = info
    }

    fileprivate func onPinchInfo(_ info: PinchInfo?) {
        guard pinchInfo != info else { return }
        pinchInfoSubject.send(info)
        pinchInfo = info
    }

    fileprivate func onFirstTouchBegan() {
        startTimeSubject.send(.now)
        startTime = .now
    }

    fileprivate func onAllTouchesEnded() {
        startTimeSubject.send(nil)
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
            model.onFirstTouchBegan()
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
            model.onAllTouchesEnded()
        } else {
            onActiveTouchesChanged()
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        activeTouches.subtract(touches)
        if activeTouches.isEmpty {
            model.onAllTouchesEnded()
        } else {
            onActiveTouchesChanged()
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        onActiveTouchesMoved()
    }

    init(model: MultipleTouchModel, frame: CGRect) {
        self.model = model
        super.init(frame: frame)
        isMultipleTouchEnabled = true
    }

    convenience init(model: MultipleTouchModel) {
        self.init(model: model, frame: CGRect.zero)
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("This class does not support NSCoding")
    }

    // MARK: private

    private var model: MultipleTouchModel

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
        model.onTouchesCount(activeTouches.count)
        model.onPanInfo(nil)
        model.onPinchInfo(nil)
        if let panTouch {
            model.onPanInfo(.init(origin: location(of: panTouch)))
        } else if let pinchTouches {
            model.onPinchInfo(.init(origin: (location(of: pinchTouches.0), location(of: pinchTouches.1))))
        }
    }

    private func onActiveTouchesMoved() {
        if let info = model.panInfo, let panTouch {
            model.onPanInfo(.init(origin: info.origin, offset: Vector2(location(of: panTouch)) - Vector2(info.origin)))
        } else if let info = model.pinchInfo, let pinchTouches {
            model.onPinchInfo(.init(
                origin: info.origin,
                offset: (Vector2(location(of: pinchTouches.0)) - Vector2(info.origin.0), Vector2(location(of: pinchTouches.1)) - Vector2(info.origin.1))
            ))
        }
    }
}

// MARK: - MultipleTouchModifier

struct MultipleTouchModifier: ViewModifier {
    @Binding var model: MultipleTouchModel

    func body(content: Content) -> some View {
        content.overlay { Representable(model: $model) }
    }

    // MARK: private

    private struct Representable: UIViewRepresentable {
        @Binding var model: MultipleTouchModel

        func makeUIView(context: Context) -> UIView { MultipleTouchView(model: model) }

        func updateUIView(_ uiView: UIView, context: Context) {}
    }
}
