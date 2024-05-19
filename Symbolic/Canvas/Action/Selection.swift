import Foundation
import SwiftUI

class SelectionModel: Store {
    @Trackable var selectedPathIds: Set<UUID> = []

    func update(pathIds: Set<UUID>) {
        update {
            $0(\._selectedPathIds, pathIds)
        }
    }
}

fileprivate var selectedPathsSelector: [Path] {
    let pathIds = store.selection.selectedPathIds
    return store.path.paths.filter { pathIds.contains($0.id) }
}

struct Selection: View {
    @Selected var selectedPaths = selectedPathsSelector
    @Selected var toView = store.viewport.toView

    @State private var dashPhase: CGFloat = 0

    var bounds: CGRect? {
        guard let first = selectedPaths.first else { return nil }
        var bounds = selectedPaths.dropFirst().reduce(into: first.boundingRect) { rect, path in rect = rect.union(path.boundingRect) }
        bounds = bounds.applying(toView)
        bounds = bounds.insetBy(dx: -4, dy: -4)
        return bounds
    }

    var body: some View {
        if let bounds {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.blue.opacity(0.5), style: .init(lineWidth: 2, dash: [8], dashPhase: dashPhase))
                .frame(width: bounds.width, height: bounds.height)
                .position(bounds.center)
                .modifier(AnimatedValue(value: $dashPhase, from: 0, to: 16, animation: .linear(duration: 0.4).repeatForever(autoreverses: false)))
        }
        ForEach(selectedPaths) {
            let rect = $0.boundingRect.applying(toView)
            RoundedRectangle(cornerRadius: 2)
                .fill(.blue.opacity(0.2))
                .stroke(.blue.opacity(0.5))
                .frame(width: rect.width, height: rect.height)
                .position(rect.center)
        }
    }
}
