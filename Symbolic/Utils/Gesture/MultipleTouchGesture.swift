import Combine
import Foundation
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

    var onPinch: ((PinchInfo) -> Void)?
    var onPinchEnd: ((PinchInfo) -> Void)?
}

// MARK: - MultipleTouchPressModel

class MultipleTouchPressModel: CancellableHolder {
    var cancellables = Set<AnyCancellable>()

    func onPress(_ callback: @escaping () -> Void) {
        pressSubject
            .sink(receiveValue: callback)
            .store(in: self)
    }

    func onPressEnd(_ callback: @escaping (_ cancelled: Bool) -> Void) {
        pressEndSubject
            .sink(receiveValue: callback)
            .store(in: self)
    }

    func onTap(_ callback: @escaping (TapInfo) -> Void) {
        tapSubject
            .sink(receiveValue: callback)
            .store(in: self)
    }

    func onLongPress(_ callback: @escaping (PanInfo) -> Void) {
        longPressSubject
            .sink(receiveValue: callback)
            .store(in: self)
    }

    func onLongPressEnd(_ callback: @escaping (PanInfo) -> Void) {
        longPressEndSubject
            .sink(receiveValue: callback)
            .store(in: self)
    }

    func onDrag(_ callback: @escaping (PanInfo) -> Void) {
        dragSubject
            .sink(receiveValue: callback)
            .store(in: self)
    }

    func onDragEnd(_ callback: @escaping (PanInfo) -> Void) {
        dragEndSubject
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

    fileprivate let pressSubject = PassthroughSubject<Void, Never>()
    fileprivate let pressEndSubject = PassthroughSubject<Bool, Never>()

    fileprivate let tapSubject = PassthroughSubject<TapInfo, Never>()
    fileprivate let longPressSubject = PassthroughSubject<PanInfo, Never>()
    fileprivate let longPressEndSubject = PassthroughSubject<PanInfo, Never>()

    fileprivate let dragSubject = PassthroughSubject<PanInfo, Never>()
    fileprivate let dragEndSubject = PassthroughSubject<PanInfo, Never>()

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
        multipleTouch.$startTime
            .sink { time in
                guard time != nil else { return }
                self.onPressStart()
                self.onPressChange()
            }
            .store(in: model)
        multipleTouch.$panInfo
            .sink { info in
                if let info {
                    self.context?.onValue(info)
                    self.onPressChange()
                }
            }
            .store(in: model)
        multipleTouch.$touchesCount
            .sink { count in
                guard count != 1 else { return }
                if count == 0 {
                    self.onPressEnd()
                } else if count > 1 {
                    self.onPressCancel()
                }
            }
            .store(in: model)
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
        let _r = subtracer.range("press start", type: .intent); defer { _r() }
        context = .init()
        setupLongPress()
        model.pressSubject.send()
    }

    private func onPressChange() {
        guard let context, let value = context.lastValue else { return }
        let _r = subtracer.range("press change", type: .intent); defer { _r() }
        if !isPress {
            if !context.longPressStarted || !configs.holdLongPressOnDrag {
                resetLongPress()
            }
            model.dragSubject.send(value)
        }
    }

    private func onPressEnd() {
        guard let context, let value = context.lastValue else { return }
        let _r = subtracer.range("press end", type: .intent); defer { _r() }
        if isPress {
            resetLongPress()
            if !context.longPressStarted {
                let count = tapCount
                model.tapSubject.send(.init(location: value.current, count: count))
                model.pendingRepeatedTapInfo = .init(count: count, time: Date(), location: value.current)
            }
        } else {
            model.pendingRepeatedTapInfo = nil
            model.dragEndSubject.send(value)
            if configs.holdLongPressOnDrag {
                resetLongPress()
            }
        }
        model.pressEndSubject.send(false)
        self.context = nil
    }

    private func onPressCancel() {
        guard context != nil else { return }
        let _r = subtracer.range("press cancel", type: .intent); defer { _r() }
        resetLongPress(cancel: true)
        model.pressEndSubject.send(true)
        context = nil
    }

    // MARK: long press

    private func setupLongPress() {
        guard context != nil else { return }
        let _r = subtracer.range("setup long press"); defer { _r() }
        let longPressTimeout = DispatchWorkItem {
            guard let value = context?.lastValue else { return }
            self.model.longPressSubject.send(value)
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
                model.longPressEndSubject.send(value)
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
            .onReceive(multipleTouch.$pinchInfo) { info in
                if let info {
                    gesture.onPinch?(info)
                } else if let info = multipleTouch.pinchInfo {
                    gesture.onPinchEnd?(info)
                }
            }
            .onReceive(multipleTouchPress.pressSubject) {
                gesture.onPress?()
            }
            .onReceive(multipleTouchPress.pressEndSubject) {
                gesture.onPressEnd?($0)
            }
            .onReceive(multipleTouchPress.tapSubject) {
                gesture.onTap?($0)
            }
            .onReceive(multipleTouchPress.longPressSubject) {
                gesture.onLongPress?($0)
            }
            .onReceive(multipleTouchPress.longPressEndSubject) {
                gesture.onLongPressEnd?($0)
            }
            .onReceive(multipleTouchPress.dragSubject) {
                gesture.onDrag?($0)
            }
            .onReceive(multipleTouchPress.dragEndSubject) {
                gesture.onDragEnd?($0)
            }
            .onAppear {
                pressDetector.subscribe()
            }
            .onDisappear {
                gesture.onPressEnd?(true)
            }
    }

    @State private var multipleTouch = MultipleTouchModel(configs: .init(inGlobalCoordinate: true))
    @State private var multipleTouchPress = MultipleTouchPressModel(configs: .init(durationThreshold: 0.2))

    private var pressDetector: MultipleTouchPressDetector { .init(multipleTouch: multipleTouch, model: multipleTouchPress) }
}

extension View {
    func multipleTouchGesture(_ gesture: MultipleTouchGesture) -> some View {
        modifier(MultipleTouchGestureModifier(gesture: gesture))
    }
}
