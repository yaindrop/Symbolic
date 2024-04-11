//
//  PressDetector.swift
//  Symbolic
//
//  Created by Yaindrop on 2024/4/10.
//

import Combine
import Foundation

struct TapInfo {
    var location: CGPoint
    var isDoubleTap: Bool = false
}

class PressDetector: ObservableObject {
    static let pressOffsetThreshold: CGFloat = 10
    static let tapDurationThreshold: TimeInterval = 1
    static let doubleTapIntervalThreshold: TimeInterval = 0.5
    static let doubleTapOffsetThreshold: CGFloat = 20

    var pressLocation: CGPoint? { isPress ? touchContext.panInfo?.origin : nil }

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
        return Date().timeIntervalSince(beganTime) < PressDetector.doubleTapIntervalThreshold
    }

    private var pendingDoubleTapTime: Date?
    private var pendingDoubleTapLocation: CGPoint?
    private var canEndAsDoubleTap: Bool {
        guard let prevTime = pendingDoubleTapTime else { return false }
        guard let prevLocation = pendingDoubleTapLocation else { return false }
        guard let currLocation = pressLocation else { return false }
        return Date().timeIntervalSince(prevTime) < PressDetector.doubleTapIntervalThreshold && prevLocation.distance(to: currLocation) < PressDetector.doubleTapOffsetThreshold
    }

    private func onTouchEnded() {
        var isSingleTap = canEndAsTap
        if isSingleTap, let location = pressLocation {
            let isDoubleTap = canEndAsDoubleTap
            tapSubject.send(TapInfo(location: location, isDoubleTap: isDoubleTap))
            isSingleTap = !isDoubleTap
        }
        if isSingleTap {
            pendingDoubleTapTime = Date()
            pendingDoubleTapLocation = pressLocation
        } else {
            pendingDoubleTapTime = nil
            pendingDoubleTapLocation = nil
        }
    }
}
