import Combine
import Foundation

struct TapInfo {
    let location: Point2
    let count: Int
}

// MARK: - PressDetector

class MultipleTouchPressDetector: ObservableObject {
    struct Configs {
        let pressOffsetThreshold: Scalar = 10
        let tapDurationThreshold: TimeInterval = 1
        let repeatedTapIntervalThreshold: TimeInterval = 0.5
        let repeatedTapOffsetThreshold: Scalar = 20
    }

    var pressLocation: Point2? { isPress ? touchContext.panInfo?.origin : nil }

    private(set) var tapSubject = PassthroughSubject<TapInfo, Never>()

    func onTap(_ callback: @escaping (TapInfo) -> Void) {
        tapSubject.sink { value in callback(value) }.store(in: &subscriptions)
    }

    init(touchContext: MultipleTouchContext, configs: Configs = Configs()) {
        self.touchContext = touchContext
        self.configs = configs
        touchContext.$active.sink { active in if !active { self.onTouchEnded() }}.store(in: &subscriptions)
    }

    // MARK: private

    private let touchContext: MultipleTouchContext
    private let configs: Configs
    private var subscriptions = Set<AnyCancellable>()

    private var isPress: Bool { return touchContext.maxTouchesCount == 1 && touchContext.maxPanOffset < configs.pressOffsetThreshold }

    private var canEndAsTap: Bool {
        guard let beganTime = touchContext.firstTouchBeganTime else { return false }
        return Date().timeIntervalSince(beganTime) < configs.tapDurationThreshold
    }

    private struct RepeatedTapInfo {
        let count: Int
        let time: Date
        let location: Point2
    }

    private var pendingRepeatedTapInfo: RepeatedTapInfo?
    private var canEndAsRepeatedTap: Bool {
        guard let info = pendingRepeatedTapInfo,
              let currLocation = pressLocation else { return false }
        return Date().timeIntervalSince(info.time) < configs.repeatedTapIntervalThreshold && info.location.distance(to: currLocation) < configs.repeatedTapOffsetThreshold
    }

    private func onTouchEnded() {
        if canEndAsTap, let location = pressLocation {
            let count: Int = canEndAsRepeatedTap ? pendingRepeatedTapInfo!.count + 1 : 1
            let info = TapInfo(location: location, count: count)
            tapSubject.send(info)
            pendingRepeatedTapInfo = RepeatedTapInfo(count: count, time: Date(), location: location)
        } else {
            pendingRepeatedTapInfo = nil
        }
    }
}
