import Combine
import SwiftUI
import UIKit

private let subtracer = tracer.tagged("MultipleTouch")

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
    public var description: String { "(\(origin.shortDescription), \(offset.shortDescription))" }
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

class MultipleTouchModel: ObservableObject {
    struct Configs {
        var enableTouchDebugView = false
        var inGlobalCoordinate = false
    }

    struct StartedTouch {
        let time: Date
        let position: Point2
    }

    let configs: Configs

    @Published private(set) var started: StartedTouch?
    @Published private(set) var touchesCount: Int = 0

    @Published fileprivate(set) var panInfo: PanInfo?
    @Published fileprivate(set) var pinchInfo: PinchInfo?

    var active: Bool { started != nil }

    init(configs: Configs = .init()) {
        self.configs = configs
    }
}

// MARK: private

private extension MultipleTouchModel {
    func onFirstTouchBegan(position: Point2) {
        let _r = subtracer.range("onFirstTouchBegan"); defer { _r() }
        started = .init(time: .now, position: position)
    }

    func onAllTouchesEnded() {
        let _r = subtracer.range("onAllTouchesEnded"); defer { _r() }
        onTouchesChanged(count: 0)
        started = nil
    }

    func onTouchesChanged(count: Int) {
        let _r = subtracer.range("onTouchesChanged count=\(count)"); defer { _r() }
        touchesCount = count
        if panInfo != nil {
            panInfo = nil
        }
        if pinchInfo != nil {
            pinchInfo = nil
        }
    }
}

// MARK: - MultipleTouchView

class MultipleTouchView: TouchDebugView {
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        guard let first = touches.first else { return }
        if activeTouches.isEmpty {
            model.onFirstTouchBegan(position: location(of: first))
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
        enableTouchDebugView = model.configs.enableTouchDebugView
    }

    convenience init(model: MultipleTouchModel) {
        self.init(model: model, frame: CGRect.zero)
    }

    @available(*, unavailable)
    required init(coder _: NSCoder) {
        fatalError("This class does not support NSCoding")
    }

    fileprivate var model: MultipleTouchModel
    fileprivate var activeTouches = Set<UITouch>()
}

// MARK: private

private extension MultipleTouchView {
    var panTouch: UITouch? { activeTouches.count == 1 ? activeTouches.first : nil }
    var pinchTouches: (UITouch, UITouch)? {
        if activeTouches.count != 2 {
            return nil
        }
        let touches = Array(activeTouches)
        return (touches[0], touches[1])
    }

    func location(of touch: UITouch) -> Point2 { touch.location(in: model.configs.inGlobalCoordinate ? nil : self) }

    func onActiveTouchesChanged() {
        model.onTouchesChanged(count: activeTouches.count)
        if let panTouch {
            model.panInfo = .init(origin: location(of: panTouch))
        } else if let pinchTouches {
            model.pinchInfo = .init(origin: (location(of: pinchTouches.0), location(of: pinchTouches.1)))
        }
    }

    func onActiveTouchesMoved() {
        if let info = model.panInfo, let panTouch {
            model.panInfo = .init(origin: info.origin, offset: Vector2(location(of: panTouch)) - Vector2(info.origin))
        } else if let info = model.pinchInfo, let pinchTouches {
            model.pinchInfo = .init(
                origin: info.origin,
                offset: (Vector2(location(of: pinchTouches.0)) - Vector2(info.origin.0), Vector2(location(of: pinchTouches.1)) - Vector2(info.origin.1))
            )
        }
    }
}

// MARK: - MultipleTouchModifier

struct MultipleTouchModifier: ViewModifier {
    let model: MultipleTouchModel

    func body(content: Content) -> some View {
        content
            .overlay { Representable(model: model) }
            .onDisappear {
                model.onAllTouchesEnded()
            }
    }
}

// MARK: private

private struct Representable: UIViewRepresentable {
    let model: MultipleTouchModel

    func makeUIView(context _: Context) -> UIView { MultipleTouchView(model: model) }

    func updateUIView(_: UIView, context _: Context) {}
}
