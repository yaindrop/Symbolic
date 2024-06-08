import SwiftUI

struct CanvasActionPanel: View, TracedView, SelectorHolder {
    class Selector: SelectorBase {
        @Selected({ Array(global.canvasAction.triggering).map { $0.hint } }) var triggeringHints
        @Selected({ Array(global.canvasAction.continuous).map { $0.hint } }) var continuousHints
        @Selected({ Array(global.canvasAction.instant).map { $0.hint } }) var instantHints
    }

    @SelectorWrapper var selector

    var body: some View { trace {
        setupSelector {
            VStack(alignment: .leading) {
                if !selector.continuousHints.isEmpty {
                    Text(selector.continuousHints.joined(separator: " "))
                        .padding(8)
                        .background(.green.opacity(0.5))
                        .clipRounded(radius: 12)
                }
                if !selector.triggeringHints.isEmpty {
                    Text(selector.triggeringHints.joined(separator: " "))
                        .padding(8)
                        .background(.orange.opacity(0.5))
                        .clipRounded(radius: 12)
                }
                if !selector.instantHints.isEmpty {
                    Text(selector.instantHints.joined(separator: " "))
                        .padding(8)
                        .background(.blue.opacity(0.5))
                        .clipRounded(radius: 12)
                }
            }
            .font(.footnote)
        }
    } }
}
