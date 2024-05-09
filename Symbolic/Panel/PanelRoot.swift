import Foundation
import SwiftUI

// MARK: - PanelIdKey

private struct PanelIdKey: EnvironmentKey {
    typealias Value = UUID
    static let defaultValue = UUID()
}

extension EnvironmentValues {
    var panelId: UUID {
        get { self[PanelIdKey.self] }
        set { self[PanelIdKey.self] = newValue }
    }
}

// MARK: - PanelData

struct PanelData {
    let id: UUID = UUID()
    let view: AnyView
    var origin: Point2 = .zero
    var size: CGSize = .zero
    var zIndex: Double

    var rect: CGRect { CGRect(origin: origin, size: size) }
}

// MARK: - PanelModel

class PanelModel: ObservableObject {
    @Published var idToPanel: [UUID: PanelData] = [:]
    @Published var panelIds: [UUID] = []
    @Published var rootSize: CGSize = .zero

    var panels: [PanelData] { panelIds.compactMap { idToPanel[$0] } }
}

extension PanelModel {
    func register(@ViewBuilder _ panel: @escaping () -> any View) {
        let panelData = PanelData(view: AnyView(panel()), zIndex: Double(idToPanel.count))
        idToPanel[panelData.id] = panelData
        panelIds.append(panelData.id)
    }

    func deregister(panelId: UUID) {
        idToPanel.removeValue(forKey: panelId)
        panelIds.removeAll { $0 == panelId }
    }

    private func sort() {
        panelIds.sort {
            guard let data0 = idToPanel[$0] else { return true }
            guard let data1 = idToPanel[$1] else { return false }
            return data0.zIndex < data1.zIndex
        }
    }
}

extension PanelModel {
    func onMoving(panelId: UUID, origin: Point2) {
        guard var panel = idToPanel[panelId] else { return }
        panel.origin = origin
        idToPanel[panelId] = panel
    }

    func onMoved(panelId: UUID, origin: Point2, inertia: Vector2) {
        guard var panel = idToPanel[panelId] else { return }
        panel.origin = origin
        idToPanel[panelId] = panel
        withAnimation {
            if inertia.length > 240 {
                idToPanel[panelId]?.origin = origin + inertia / 4
            }
            clampOrigin(panelId: panelId)
        }
    }

    func clampOrigin(panelId: UUID) {
        guard var panel = idToPanel[panelId] else { return }
        panel.origin = panel.rect.clamped(by: CGRect(rootSize)).origin
        idToPanel[panelId] = panel
    }

    func moveGesture(panelId: UUID) -> MultipleGestureModifier<Point2>? {
        guard let panel = idToPanel[panelId] else { return nil }
        return MultipleGestureModifier(
            panel.origin,
            configs: .init(coordinateSpace: .global),
            onDrag: { v, c in self.onMoving(panelId: panel.id, origin: c + v.offset) },
            onDragEnd: { v, c in self.onMoved(panelId: panel.id, origin: c + v.offset, inertia: v.inertia) }
        )
    }
}

// MARK: - PanelRoot

struct PanelRoot: View {
    @EnvironmentObject var model: PanelModel

    var body: some View {
        ZStack {
            ForEach(model.panels, id: \.id) { panel in
                panel.view
                    .readSize { model.idToPanel[panel.id]?.size = $0 }
                    .offset(x: panel.origin.x, y: panel.origin.y)
                    .zIndex(panel.zIndex)
                    .environment(\.panelId, panel.id)
                    .atCornerPosition(.topLeading)
                    .onChange(of: panel.size) {
                        withAnimation {
                            model.clampOrigin(panelId: panel.id)
                        }
                    }
            }
        }
        .readSize { model.rootSize = $0 }
        .onChange(of: model.rootSize) {
            withAnimation {
                for id in model.panelIds {
                    model.clampOrigin(panelId: id)
                }
            }
        }
    }
}
