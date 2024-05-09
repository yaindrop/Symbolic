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

    var rect: CGRect { .init(origin: origin, size: size) }
}

// MARK: - PanelModel

class PanelModel: ObservableObject {
    @Published var idToPanel: [UUID: PanelData] = [:]
    @Published var panelIds: [UUID] = []
    @Published var rootSize: CGSize = .zero

    var panels: [PanelData] { panelIds.compactMap { idToPanel[$0] } }
    var rootRect: CGRect { .init(rootSize) }
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
            var finalOrigin = origin
            if inertia.length > 240 {
                finalOrigin = origin + inertia / 4
            }
            finalOrigin = CGRect(origin: finalOrigin, size: panel.size).clamped(by: CGRect(rootSize)).origin
            panel.origin = finalOrigin
            idToPanel[panelId] = panel
            let affinities = getAffinities(of: panelId)
            if let a = affinities.first { $0.axis == .horizontal } {
                panel.origin += offset(panel: panel, by: a)
//                print(offset(panel: panel, by: a))
            }
            if let a = affinities.first { $0.axis == .vertical } {
                panel.origin += offset(panel: panel, by: a)
//                print(offset(panel: panel, by: a))
            }
            idToPanel[panelId] = panel
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
                    .atAlignPosition(.topLeading)
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

enum PanelAffinity {
    struct Root {
        let axis: Axis
        let align: EdgeAlign
    }

    struct Peer {
        let peerId: UUID
        let axis: Axis
        let selfAlign: EdgeAlign
        let peerAlign: EdgeAlign
    }

    case root(Root)
    case peer(Peer)

    var axis: Axis {
        switch self {
        case let .root(root): root.axis
        case let .peer(peer): peer.axis
        }
    }
}

extension PanelAffinity.Root: CustomStringConvertible {
    var description: String { "(\(axis), \(align))" }
}

extension PanelAffinity.Peer: CustomStringConvertible {
    var description: String { "(\(axis), \(selfAlign) to \(peerAlign) of \(peerId)" }
}

extension PanelAffinity: CustomStringConvertible {
    var description: String {
        switch self {
        case let .root(root): "Root\(root.description)"
        case let .peer(peer): "Peer\(peer.description)"
        }
    }
}

extension PanelModel {
    static let rootAffinityThreshold = 24.0
    static let peerAffinityThreshold = 12.0

    private func getKeyPath(axis: Axis, align: EdgeAlign) -> KeyPath<CGRect, Scalar> {
        switch axis {
        case .horizontal:
            switch align {
            case .start: \.minX
            case .center: \.midX
            case .end: \.maxX
            }
        case .vertical:
            switch align {
            case .start: \.minY
            case .center: \.midY
            case .end: \.maxY
            }
        }
    }

    private func getRootAffinityCandidates(of rect: CGRect) -> [PanelAffinity] {
        Axis.allCases.compactMap { axis in
            let threshold = Self.rootAffinityThreshold
            let align = EdgeAlign.allCases.first { align in
                let kp = getKeyPath(axis: axis, align: align)
                return abs(rect[keyPath: kp] - rootRect[keyPath: kp]) < threshold
            }
            guard let align else { return nil }
            return .root(.init(axis: axis, align: align))
        }
    }

    private func getPeerAffinityCandidates(of rect: CGRect, peer: PanelData) -> [PanelAffinity] {
        Axis.allCases.flatMap { axis in
            EdgeAlign.allCases.flatMap { selfAlign in
                EdgeAlign.allCases.compactMap { peerAlign in
                    if abs(rect[keyPath: getKeyPath(axis: axis, align: selfAlign)] - peer.rect[keyPath: getKeyPath(axis: axis, align: peerAlign)]) < Self.peerAffinityThreshold {
                        .peer(.init(peerId: peer.id, axis: axis, selfAlign: selfAlign, peerAlign: peerAlign))
                    } else {
                        nil
                    }
                }
            }
        }
    }

    private func getAffinities(of panelId: UUID) -> [PanelAffinity] {
        guard let panel = idToPanel[panelId] else { return [] }
        var candidates = getRootAffinityCandidates(of: panel.rect)
        for peer in panels {
            guard peer.id != panelId else { continue }
            candidates += getPeerAffinityCandidates(of: panel.rect, peer: peer)
        }
        return candidates
    }

    private func offset(panel: PanelData, by affinity: PanelAffinity.Root) -> Vector2 {
        let kp = getKeyPath(axis: affinity.axis, align: affinity.align)
        let offset = rootRect[keyPath: kp] - panel.rect[keyPath: kp]

        switch affinity.axis {
        case .horizontal: return .init(offset, 0)
        case .vertical: return .init(0, offset)
        }
    }

    private func offset(panel: PanelData, by affinity: PanelAffinity.Peer) -> Vector2 {
        guard let peerPanel = idToPanel[affinity.peerId] else { return .zero }

        let panelKeyPath = getKeyPath(axis: affinity.axis, align: affinity.selfAlign)
        let peerKeyPath = getKeyPath(axis: affinity.axis, align: affinity.peerAlign)
        let offset = peerPanel.rect[keyPath: peerKeyPath] - panel.rect[keyPath: panelKeyPath]

        switch affinity.axis {
        case .horizontal: return .init(offset, 0)
        case .vertical: return .init(0, offset)
        }
    }

    private func offset(panel: PanelData, by affinity: PanelAffinity) -> Vector2 {
        switch affinity {
        case let .root(root): offset(panel: panel, by: root)
        case let .peer(peer): offset(panel: panel, by: peer)
        }
    }
}
