//
//  PressDetector.swift
//  Symbolic
//
//  Created by Yaindrop on 2024/4/10.
//

import Combine
import Foundation

class PressDetector: ObservableObject {
    static let pressOffsetThreshold: CGFloat = 10
    static let tapDurationThreshold: TimeInterval = 1
    static let doubleTapIntervalThreshold: TimeInterval = 0.5
    static let doubleTapOffsetThreshold: CGFloat = 20

    var isPress: Bool { return context.maxTouchesCount == 1 && context.maxPanOffset < PressDetector.pressOffsetThreshold }
    var pressLocation: CGPoint? { isPress ? context.panInfo?.origin : nil }

    var tapSubject = PassthroughSubject<CGPoint, Never>()
    var doubleTapSubject = PassthroughSubject<CGPoint, Never>()

    func onTap(_ callback: @escaping (CGPoint) -> Void) {
        tapSubject.sink(receiveValue: { value in callback(value) }).store(in: &subscriptions)
    }

    func onDoubleTap(_ callback: @escaping (CGPoint) -> Void) {
        doubleTapSubject.sink(receiveValue: { value in callback(value) }).store(in: &subscriptions)
    }

    init(context: MultipleTouchContext) {
        self.context = context
        context.$active.sink(
            receiveValue: { active in
                if !active {
                    self.onTouchEnded()
                }
            }
        )
        .store(in: &subscriptions)
    }

    // MARK: private

    private let context: MultipleTouchContext
    private var subscriptions = Set<AnyCancellable>()

    private var canEndAsTap: Bool {
        guard let beganTime = context.firstTouchBeganTime else { return false }
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
            tapSubject.send(location)
            if canEndAsDoubleTap {
                doubleTapSubject.send(location)
                isSingleTap = false
            }
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
