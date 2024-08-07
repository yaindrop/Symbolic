import SwiftUI

// MARK: - CanvasActionStore

class CanvasActionStore: Store {
    @Trackable var triggering = Set<CanvasAction.Triggering>()
    @Trackable var continuous = Set<CanvasAction.Continuous>()
    @Trackable var instant = Set<CanvasAction.Instant>()
}

extension CanvasActionStore {
    func start(triggering action: CanvasAction.Triggering) {
        update { $0(\._triggering, triggering.cloned { $0.insert(action) }) }
    }

    func end(triggering action: CanvasAction.Triggering) {
        update { $0(\._triggering, triggering.cloned { $0.remove(action) }) }
    }

    func start(continuous action: CanvasAction.Continuous) {
        update { $0(\._continuous, continuous.cloned { $0.insert(action) }) }
    }

    func end(continuous action: CanvasAction.Continuous) {
        update { $0(\._continuous, continuous.cloned { $0.remove(action) }) }
    }

    func on(instant action: CanvasAction.Instant) {
        if instant.contains(action) {
            return
        }
        update { $0(\._instant, instant.cloned { $0.insert(action) }) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.update { $0(\._instant, self.instant.cloned { $0.remove(action) }) }
        }
    }
}

struct CanvasActionView: View, TracedView, SelectorHolder {
    class Selector: SelectorBase {
        @Selected({ global.canvasAction.triggering.map { $0.hint } }) var triggeringHints
        @Selected({ global.canvasAction.continuous.map { $0.hint } }) var continuousHints
        @Selected({ global.canvasAction.instant.map { $0.hint } }) var instantHints
    }

    @SelectorWrapper var selector

    var body: some View { trace {
        setupSelector {
            content
        }
    } }
}

private extension CanvasActionView {
    var content: some View {
        HStack {
            if empty {
                Text(" ")
                    .padding(size: .init(6, 3))
                    .opacity(0)
            }
            if !selector.continuousHints.isEmpty {
                Text(selector.continuousHints.joined(separator: " "))
                    .padding(size: .init(6, 3))
                    .background(.green.opacity(0.6))
                    .clipRounded(radius: 6)
            }
            if !selector.triggeringHints.isEmpty {
                Text(selector.triggeringHints.joined(separator: " "))
                    .padding(size: .init(6, 3))
                    .background(.orange.opacity(0.6))
                    .clipRounded(radius: 6)
            }
            if !selector.instantHints.isEmpty {
                Text(selector.instantHints.joined(separator: " "))
                    .padding(size: .init(6, 3))
                    .background(.blue.opacity(0.6))
                    .clipRounded(radius: 6)
            }
        }
        .font(.system(size: 12))
        .aligned(axis: .horizontal, .start)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
        .background { Color.green.opacity(debugCanvasOverlay ? 0.2 : 0).allowsHitTesting(false) }
    }

    var empty: Bool {
        selector.continuousHints.isEmpty && selector.triggeringHints.isEmpty && selector.instantHints.isEmpty
    }
}
