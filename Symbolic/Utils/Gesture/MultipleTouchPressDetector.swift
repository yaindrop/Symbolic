import Combine
import Foundation

struct TapInfo {
    let location: Point2
    let count: Int
}

// MARK: - MultipleTouchPressModel

class MultipleTouchPressModel: CancellableHolder {
    var cancellables = Set<AnyCancellable>()

    // MARK: Configs

    struct Configs {
        var distanceThreshold: Scalar = 10 // tap or long press when smaller, drag when greater
        var durationThreshold: TimeInterval = 0.5 // tap when smaller, long press when greater
        var repeatedTapIntervalThreshold: TimeInterval = 0.5 // repeated tap when smaller, separated tap when greater
        var repeatedTapDistanceThreshold: Scalar = 20 // repeated tap when smaller, separated tap when greater
        var holdLongPressOnDrag: Bool = true // whether to continue long press after drag start
    }

    func onPress(_ callback: @escaping () -> Void) {
        pressSubject
            .sink(receiveValue: callback)
            .store(in: self)
    }

    func onPressEnd(_ callback: @escaping () -> Void) {
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

    init(configs: Configs) {
        self.configs = configs
    }

    // MARK: fileprivate

    fileprivate struct Context {
        var maxDistance: Scalar = 0

        var longPressTimeout: DispatchWorkItem?
        var longPressStarted = false

        mutating func onValue(_ panInfo: PanInfo) {
            maxDistance = max(maxDistance, panInfo.offset.length)
        }
    }

    fileprivate let configs: Configs

    fileprivate var context: Context?

    fileprivate let pressSubject = PassthroughSubject<Void, Never>()
    fileprivate let pressEndSubject = PassthroughSubject<Void, Never>()

    fileprivate let tapSubject = PassthroughSubject<TapInfo, Never>()
    fileprivate let longPressSubject = PassthroughSubject<PanInfo, Never>()
    fileprivate let longPressEndSubject = PassthroughSubject<PanInfo, Never>()

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
                self.onPressStarted()
                self.onPressChanged()
            }
            .store(in: model)
        multipleTouch.$panInfo
            .sink { info in
                if let info {
                    self.context?.onValue(info)
                    self.onPressChanged()
                }
            }
            .store(in: model)
        multipleTouch.$touchesCount
            .sink { count in
                guard count != 1 else { return }
                if count == 0 {
                    self.onPressEnded()
                } else if count > 1 {
                    self.onPressCanceled()
                }
            }
            .store(in: model)
    }

    // MARK: private

    private var configs: MultipleTouchPressModel.Configs { model.configs }

    private var context: MultipleTouchPressModel.Context? {
        get { model.context }
        nonmutating set { model.context = newValue }
    }

    private var panInfo: PanInfo? { multipleTouch.panInfo }

    private var location: Point2? { panInfo?.current }

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

    private func onPressStarted() {
        context = .init()
        setupLongPress()
        model.pressSubject.send()
    }

    private func onPressChanged() {
        guard let context else { return }
        if !isPress {
            if !context.longPressStarted || !configs.holdLongPressOnDrag {
                onPressCanceled()
            }
        }
    }

    private func onPressEnded() {
        guard let context, let panInfo else { return }
        if isPress {
            if context.longPressStarted {
                model.longPressEndSubject.send(panInfo)
            } else {
                let count = tapCount
                model.tapSubject.send(.init(location: panInfo.current, count: count))
                model.pendingRepeatedTapInfo = .init(count: count, time: Date(), location: panInfo.current)
            }
        } else {
            model.pendingRepeatedTapInfo = nil
            if configs.holdLongPressOnDrag {
                resetLongPress()
            }
        }
        model.pressEndSubject.send()
        self.context = nil
    }

    private func onPressCanceled() {
        resetLongPress()
        model.pressEndSubject.send()
        context = nil
    }

    // MARK: long press

    private func setupLongPress() {
        guard context != nil else { return }
        let longPressTimeout = DispatchWorkItem {
            guard let panInfo else { return }
            self.model.longPressSubject.send(panInfo)
            self.context?.longPressStarted = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + configs.durationThreshold, execute: longPressTimeout)
        context?.longPressTimeout = longPressTimeout
    }

    private func resetLongPress() {
        guard let context else { return }
        if let timeout = context.longPressTimeout {
            self.context?.longPressTimeout = nil
            timeout.cancel()
        }
        if context.longPressStarted {
            self.context?.longPressStarted = false
            guard let panInfo else { return }
            model.longPressEndSubject.send(panInfo)
        }
    }
}
