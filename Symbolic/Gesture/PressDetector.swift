import Combine
import Foundation

struct TapInfo {
    let location: Point2
    let count: Int
}

// MARK: - PressDetector

class PressDetector: ObservableObject {
    static let pressOffsetThreshold: CGFloat = 10
    static let tapDurationThreshold: TimeInterval = 1
    static let repeatedTapIntervalThreshold: TimeInterval = 0.5
    static let repeatedTapOffsetThreshold: CGFloat = 20

    var pressLocation: Point2? { isPress ? touchContext.panInfo?.origin : nil }

    var tapSubject = PassthroughSubject<TapInfo, Never>()

    func onTap(_ callback: @escaping (TapInfo) -> Void) {
        tapSubject.sink { value in callback(value) }.store(in: &subscriptions)
    }

    init(touchContext: MultipleTouchContext) {
        self.touchContext = touchContext
        touchContext.$active.sink { active in if !active { self.onTouchEnded() }}.store(in: &subscriptions)
    }

    // MARK: private

    private let touchContext: MultipleTouchContext
    private var subscriptions = Set<AnyCancellable>()

    private var isPress: Bool { return touchContext.maxTouchesCount == 1 && touchContext.maxPanOffset < PressDetector.pressOffsetThreshold }

    private var canEndAsTap: Bool {
        guard let beganTime = touchContext.firstTouchBeganTime else { return false }
        return Date().timeIntervalSince(beganTime) < PressDetector.tapDurationThreshold
    }

    private struct RepeatedTapInfo {
        let count: Int
        let time: Date
        let location: Point2
    }

    private var pendingRepeatedTapInfo: RepeatedTapInfo?
    private var canEndAsRepeatedTap: Bool {
        guard let info = pendingRepeatedTapInfo else { return false }
        guard let currLocation = pressLocation else { return false }
        return Date().timeIntervalSince(info.time) < PressDetector.repeatedTapIntervalThreshold && info.location.distance(to: currLocation) < PressDetector.repeatedTapOffsetThreshold
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
