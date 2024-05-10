import Combine
import Foundation

struct TapInfo {
    let location: Point2
    let count: Int
}

struct LongPressInfo {
    let location: Point2
    let isEnd: Bool
}

// MARK: - PressDetector

class MultipleTouchPressDetector: ObservableObject {
    struct Configs {
        var distanceThreshold: Scalar = 10 // tap or long press when smaller, drag when greater
        var durationThreshold: TimeInterval = 0.5 // tap when smaller, long press when greater
        var repeatedTapIntervalThreshold: TimeInterval = 0.5 // repeated tap when smaller, separated tap when greater
        var repeatedTapDistanceThreshold: Scalar = 20 // repeated tap when smaller, separated tap when greater
        var holdLongPressOnDrag: Bool = true // whether to continue long press after drag start
    }

    private struct Context {
        var maxDistance: Scalar = 0

        var longPressTimeout: DispatchWorkItem?
        var longPressStarted = false

        mutating func onValue(_ panInfo: PanInfo) {
            maxDistance = max(maxDistance, panInfo.offset.length)
        }
    }

    var location: Point2? { multipleTouch.panInfo?.current }

    let tapSubject = PassthroughSubject<TapInfo, Never>()
    let longPressSubject = PassthroughSubject<LongPressInfo, Never>()

    func onTap(_ callback: @escaping (TapInfo) -> Void) { tapSubject.sink(receiveValue: callback).store(in: &subscriptions) }

    func onLongPress(_ callback: @escaping (LongPressInfo) -> Void) { longPressSubject.sink(receiveValue: callback).store(in: &subscriptions) }

    init(multipleTouch: MultipleTouchContext, configs: Configs = Configs()) {
        self.multipleTouch = multipleTouch
        self.configs = configs
        subscribeMultipleTouch()
    }

    // MARK: private

    private let multipleTouch: MultipleTouchContext
    private let configs: Configs

    private var context: Context?
    private var subscriptions = Set<AnyCancellable>()

    private var isPress: Bool {
        guard let context else { return false }
        return context.maxDistance < configs.distanceThreshold
    }

    private struct RepeatedTapInfo {
        let count: Int
        let time: Date
        let location: Point2
    }

    private var pendingRepeatedTapInfo: RepeatedTapInfo?
    private var tapCount: Int {
        guard isPress, let info = pendingRepeatedTapInfo, let location else { return 1 }
        guard Date.now.timeIntervalSince(info.time) < configs.repeatedTapIntervalThreshold else { return 1 }
        guard info.location.distance(to: location) < configs.repeatedTapDistanceThreshold else { return 1 }
        return info.count + 1
    }

    private func subscribeMultipleTouch() {
        multipleTouch.$startTime
            .sink { time in
                if time != nil {
                    self.onPressStarted()
                    self.onPressChanged()
                } else {
                    self.onPressEnded()
                }
            }
            .store(in: &subscriptions)
        multipleTouch.$panInfo
            .sink { info in
                if let info {
                    self.context?.onValue(info)
                    self.onPressChanged()
                }
            }
            .store(in: &subscriptions)
        multipleTouch.$touchesCount
            .sink { count in
                if count != 1 {
                    self.onPressCanceled()
                }
            }
            .store(in: &subscriptions)
    }

    // MARK: stages

    private func onPressStarted() {
        context = Context()
        setupLongPress()
    }

    private func onPressChanged() {
        guard let context else { return }
        if !isPress {
            if !context.longPressStarted || !configs.holdLongPressOnDrag {
                resetLongPress()
            }
        }
    }

    private func onPressEnded() {
        guard let context, let location else { return }
        if isPress {
            if context.longPressStarted {
                longPressSubject.send(.init(location: location, isEnd: true))
            } else {
                let count = tapCount
                tapSubject.send(.init(location: location, count: count))
                pendingRepeatedTapInfo = RepeatedTapInfo(count: count, time: Date(), location: location)
            }
        } else {
            pendingRepeatedTapInfo = nil
            if configs.holdLongPressOnDrag {
                resetLongPress()
            }
        }
    }

    private func onPressCanceled() {
        resetLongPress()
        context = nil
    }

    // MARK: long press

    private func setupLongPress() {
        guard context != nil else { return }
        let longPressTimeout = DispatchWorkItem {
            guard let location = self.location else { return }
            self.longPressSubject.send(.init(location: location, isEnd: false))
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
            guard let location else { return }
            longPressSubject.send(.init(location: location, isEnd: true))
        }
    }
}
