import Combine
import SwiftUI

private let subtracer = tracer.tagged("MultipleTouchGesture")

struct TapInfo {
    let location: Point2
    let count: Int
}

// MARK: - MultipleTouchGesture

struct MultipleTouchGesture {
    struct Configs {
        var distanceThreshold: Scalar = 10 // tap or long press when smaller, drag when greater
        var durationThreshold: TimeInterval = 0.5 // tap when smaller, long press when greater
        var repeatedTapIntervalThreshold: TimeInterval = 0.5 // repeated tap when smaller, separated tap when greater
        var repeatedTapDistanceThreshold: Scalar = 20 // repeated tap when smaller, separated tap when greater
        var holdLongPressOnDrag: Bool = true // whether to continue long press after drag start
    }

    var configs: Configs = .init()

    var onPress: (() -> Void)?
    var onPressEnd: ((_ cancelled: Bool) -> Void)?

    var onTap: ((TapInfo) -> Void)?
    var onLongPress: ((PanInfo) -> Void)?
    var onLongPressEnd: ((PanInfo) -> Void)?
    var onDrag: ((PanInfo) -> Void)?
    var onDragEnd: ((PanInfo) -> Void)?

    var onPan: ((PanInfo) -> Void)?
    var onPanEnd: ((PanInfo) -> Void)?
    var onPinch: ((PinchInfo) -> Void)?
    var onPinchEnd: ((PinchInfo) -> Void)?
}

// MARK: - MultipleTouchPressModel

class MultipleTouchPressModel: CancellablesHolder {
    var cancellables = Set<AnyCancellable>()

    func onPress(_ callback: @escaping () -> Void) {
        $press
            .sink(receiveValue: callback)
            .store(in: self)
    }

    func onPressEnd(_ callback: @escaping (_ cancelled: Bool) -> Void) {
        $pressEnd
            .sink(receiveValue: callback)
            .store(in: self)
    }

    func onTap(_ callback: @escaping (TapInfo) -> Void) {
        $tap
            .sink(receiveValue: callback)
            .store(in: self)
    }

    func onLongPress(_ callback: @escaping (PanInfo) -> Void) {
        $longPress
            .sink(receiveValue: callback)
            .store(in: self)
    }

    func onLongPressEnd(_ callback: @escaping (PanInfo) -> Void) {
        $longPress
            .sink(receiveValue: callback)
            .store(in: self)
    }

    func onDrag(_ callback: @escaping (PanInfo) -> Void) {
        $drag
            .sink(receiveValue: callback)
            .store(in: self)
    }

    func onDragEnd(_ callback: @escaping (PanInfo) -> Void) {
        $dragEnd
            .sink(receiveValue: callback)
            .store(in: self)
    }

    init(configs: MultipleTouchGesture.Configs) {
        self.configs = configs
    }

    // MARK: fileprivate

    fileprivate struct Context {
        private(set) var lastValue: PanInfo?
        private(set) var maxDistance: Scalar = 0

        var longPressTimeout: DispatchWorkItem?
        var longPressStarted = false

        mutating func onValue(_ value: PanInfo) {
            lastValue = value
            maxDistance = max(maxDistance, value.offset.length)
        }
    }

    fileprivate let configs: MultipleTouchGesture.Configs

    fileprivate var context: Context?

    @Passthrough<Void> fileprivate var press
    @Passthrough<Bool> fileprivate var pressEnd

    @Passthrough<TapInfo> fileprivate var tap
    @Passthrough<PanInfo> fileprivate var longPress
    @Passthrough<PanInfo> fileprivate var longPressEnd

    @Passthrough<PanInfo> fileprivate var drag
    @Passthrough<PanInfo> fileprivate var dragEnd

    fileprivate struct RepeatedTapInfo {
        let count: Int
        let time: Date
        let location: Point2
    }

    fileprivate var pendingRepeatedTapInfo: RepeatedTapInfo?
}

// MARK: - MultipleTouchPressDetector

struct MultipleTouchPressDetector {
    let multipleTouch: MultipleTouchModel
    let model: MultipleTouchPressModel

    var pressLocation: Point2? { isPress ? location : nil }

    func subscribe() {
        model.holdCancellables {
            multipleTouch.$startTime
                .sink { time in
                    guard time != nil else { return }
                    self.onPressStart()
                    self.onPressChange()
                }
            multipleTouch.$panInfo
                .sink { info in
                    if let info {
                        self.context?.onValue(info)
                        self.onPressChange()
                    }
                }
            multipleTouch.$touchesCount
                .sink { count in
                    guard count != 1 else { return }
                    if count == 0 {
                        self.onPressEnd()
                    } else if count > 1 {
                        self.onPressCancel()
                    }
                }
        }
    }

    // MARK: private

    private var configs: MultipleTouchGesture.Configs { model.configs }

    private var context: MultipleTouchPressModel.Context? {
        get { model.context }
        nonmutating set { model.context = newValue }
    }

    private var location: Point2? { context?.lastValue?.current }

    private var isPress: Bool {
        guard let context else { return false }
        return context.maxDistance < configs.distanceThreshold
    }

    private var tapCount: Int {
        guard isPress, let info = model.pendingRepeatedTapInfo, let location else { return 1 }
        guard Date.now.timeIntervalSince(info.time) < configs.repeatedTapIntervalThreshold else { return 1 }
        guard info.location.distance(to: location) < configs.repeatedTapDistanceThreshold else { return 1 }
        return info.count + 1
    }

    // MARK: stages

    private func onPressStart() {
        let _r = subtracer.range(type: .intent, "press start"); defer { _r() }
        context = .init()
        setupLongPress()
        model.press.send()
    }

    private func onPressChange() {
        guard let context,
              let value = context.lastValue else { return }
        let _r = subtracer.range(type: .intent, "press change"); defer { _r() }
        if !isPress {
            if !context.longPressStarted || !configs.holdLongPressOnDrag {
                resetLongPress()
            }
            model.drag.send(value)
        }
    }

    private func onPressEnd() {
        guard let context,
              let value = context.lastValue else { return }
        let _r = subtracer.range(type: .intent, "press end"); defer { _r() }
        if isPress {
            resetLongPress()
            if !context.longPressStarted {
                let count = tapCount
                model.tap.send(.init(location: value.current, count: count))
                model.pendingRepeatedTapInfo = .init(count: count, time: Date(), location: value.current)
            }
        } else {
            model.pendingRepeatedTapInfo = nil
            model.dragEnd.send(value)
            if configs.holdLongPressOnDrag {
                resetLongPress()
            }
        }
        model.pressEnd.send(false)
        self.context = nil
    }

    private func onPressCancel() {
        guard context != nil else { return }
        let _r = subtracer.range(type: .intent, "press cancel"); defer { _r() }
        resetLongPress(cancel: true)
        model.pressEnd.send(true)
        context = nil
    }

    // MARK: long press

    private func setupLongPress() {
        guard context != nil else { return }
        let _r = subtracer.range("setup long press"); defer { _r() }
        let longPressTimeout = DispatchWorkItem {
            guard let value = context?.lastValue else { return }
            self.model.longPress.send(value)
            self.context?.longPressStarted = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + configs.durationThreshold, execute: longPressTimeout)
        context?.longPressTimeout = longPressTimeout
    }

    private func resetLongPress(cancel: Bool = false) {
        guard let context else { return }
        if let timeout = context.longPressTimeout {
            let _r = subtracer.range("reset long press timeout"); defer { _r() }
            self.context?.longPressTimeout = nil
            timeout.cancel()
        }
        if context.longPressStarted {
            let _r = subtracer.range("\(cancel ? "cancel" : "end") long press"); defer { _r() }
            self.context?.longPressStarted = false
            if !cancel {
                guard let value = context.lastValue else { return }
                model.longPressEnd.send(value)
            }
        }
    }
}

// MARK: - MultipleTouchGestureModifier

struct MultipleTouchGestureModifier: ViewModifier {
    var gesture: MultipleTouchGesture

    func body(content: Content) -> some View {
        content
            .modifier(MultipleTouchModifier(model: multipleTouch))
            .onReceive(multipleTouch.$panInfo) { info in
                if let info {
                    gesture.onPan?(info)
                } else if let info = multipleTouch.panInfo {
                    gesture.onPanEnd?(info)
                }
            }
            .onReceive(multipleTouch.$pinchInfo) { info in
                if let info {
                    gesture.onPinch?(info)
                } else if let info = multipleTouch.pinchInfo {
                    gesture.onPinchEnd?(info)
                }
            }
            .onReceive(multipleTouchPress.$press) {
                gesture.onPress?()
            }
            .onReceive(multipleTouchPress.$pressEnd) {
                gesture.onPressEnd?($0)
            }
            .onReceive(multipleTouchPress.$tap) {
                gesture.onTap?($0)
            }
            .onReceive(multipleTouchPress.$longPress) {
                gesture.onLongPress?($0)
            }
            .onReceive(multipleTouchPress.$longPressEnd) {
                gesture.onLongPressEnd?($0)
            }
            .onReceive(multipleTouchPress.$drag) {
                gesture.onDrag?($0)
            }
            .onReceive(multipleTouchPress.$dragEnd) {
                gesture.onDragEnd?($0)
            }
            .onAppear {
                pressDetector.subscribe()
            }
            .onDisappear {
                gesture.onPressEnd?(true)
            }
    }

    @StateObject private var multipleTouch = MultipleTouchModel(configs: .init(inGlobalCoordinate: true))
    @State private var multipleTouchPress = MultipleTouchPressModel(configs: .init(durationThreshold: 0.2))

    private var pressDetector: MultipleTouchPressDetector { .init(multipleTouch: multipleTouch, model: multipleTouchPress) }
}

extension View {
    func multipleTouchGesture(_ gesture: MultipleTouchGesture) -> some View {
        modifier(MultipleTouchGestureModifier(gesture: gesture))
    }
}
