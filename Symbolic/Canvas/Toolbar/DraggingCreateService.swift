import Combine
import SwiftUI

// MARK: - DraggingCreateStore

class DraggingCreateStore: Store {
    @Trackable var points: [Point2] = []
    @Passthrough<CGRect> var symbolRect
    @Passthrough<Path> var path
}

private extension DraggingCreateStore {
    func update(points: [Point2]) {
        update { $0(\._points, points) }
    }
}

// MARK: - DraggingCreateService

struct DraggingCreateService {
    let store: DraggingCreateStore
    let viewport: ViewportService
    let activeSymbol: ActiveSymbolService
}

// MARK: selectors

extension DraggingCreateService {
    var from: Point2? { store.points.first }
    var to: Point2 { store.points.last ?? .zero }
    var active: Bool { !store.points.isEmpty }

    var symbolRect: CGRect? {
        guard activeSymbol.editingSymbolId == nil,
              let from else { return nil }
        return .init(from: from, to: to).applying(viewport.viewToWorld)
    }

    var polyline: Polyline? {
        guard activeSymbol.editingSymbol != nil,
              store.points.count > 1 else { return nil }
        return .init(points: store.points).applying(viewport.viewToWorld)
    }

    var path: Path? {
        guard let editingSymbol = activeSymbol.editingSymbol,
              let polyline else { return nil }
        let nodes = polyline.applying(editingSymbol.worldToSymbol).fit(error: 1)
        return .init(nodeMap: .init(values: nodes) { _ in UUID() }, isClosed: false)
    }
}

// MARK: actions

extension DraggingCreateService {
    func onStart(from: Point2) {
        store.update(points: [from])
    }

    func onEnd() {
        if let symbolRect {
            store.symbolRect.send(symbolRect)
        } else if let path {
            store.path.send(path)
        }
        store.update(points: [])
    }

    func onDrag(_ info: PanInfo?) {
        guard active, let info else { return }
        store.update(points: store.points.cloned { $0.append(info.current) })
    }

    func cancel() {
        store.update(points: [])
    }
}

// MARK: - DraggingCreateView

struct DraggingCreateView: View, TracedView, SelectorHolder {
    class Selector: SelectorBase {
        @Selected({ global.draggingCreate.polyline }) var polyline
        @Selected({ global.draggingCreate.symbolRect }) var symbolRect
        @Selected({ global.viewport.worldToView }) var worldToView
    }

    @SelectorWrapper var selector

    var body: some View { trace {
        setupSelector {
            content
        }
    } }
}

private extension DraggingCreateView {
    @ViewBuilder var content: some View {
        if let polyline = selector.polyline {
            SUPath { polyline.append(to: &$0) }
                .stroke(Color(UIColor.label), style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
                .allowsHitTesting(false)
                .transformEffect(selector.worldToView)
        } else if let symbolRect = selector.symbolRect {
            Rectangle()
                .fill(Color.label.opacity(0.05))
                .framePosition(rect: symbolRect.applying(selector.worldToView))
        }
    }
}
