import Foundation
import SwiftUI

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

        var finalOrigin = origin
        if inertia.length > 240 {
            finalOrigin = origin + inertia / 4
        }

        // TODO: prioritize clamp over affinity
        finalOrigin = CGRect(origin: finalOrigin, size: panel.size).clamped(by: CGRect(rootSize)).origin
        panel.origin = finalOrigin

        panel.affinities = getAffinities(of: panel)
        panel.origin += offsetByAffinities(of: panel)

        withAnimation {
            idToPanel[panelId] = panel
        }
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

// MARK: - get affinities

fileprivate func getKeyPath(axis: Axis, align: EdgeAlign) -> KeyPath<CGRect, Scalar> {
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

extension PanelModel {
    static let rootAffinityThreshold = 24.0
    static let peerAffinityThreshold = 18.0

    typealias PanelAffinityCandidate = (affinity: PanelAffinity, distance: Scalar)
    private func getRootAffinityCandidates(of rect: CGRect) -> [PanelAffinityCandidate] {
        Axis.allCases.flatMap { axis in
            EdgeAlign.allCases.map { align in
                let kp = getKeyPath(axis: axis, align: align)
                let distance = abs(rect[keyPath: kp] - rootRect[keyPath: kp])
                return (.root(.init(axis: axis, align: align)), distance)
            }
        }
    }

    private func getPeerAffinityCandidates(of rect: CGRect, peer: PanelData) -> [PanelAffinityCandidate] {
        Axis.allCases.flatMap { axis in
            EdgeAlign.allCases.flatMap { selfAlign in
                EdgeAlign.allCases.map { peerAlign in
                    let selfKp = getKeyPath(axis: axis, align: selfAlign)
                    let peerKp = getKeyPath(axis: axis, align: peerAlign)
                    let distance = abs(rect[keyPath: selfKp] - peer.rect[keyPath: peerKp])
                    return (.peer(.init(peerId: peer.id, axis: axis, selfAlign: selfAlign, peerAlign: peerAlign)), distance)
                }
            }
        }
    }

    private func getAffinities(of panel: PanelData) -> [PanelAffinity] {
        var candidates = getRootAffinityCandidates(of: panel.rect)
        for peer in panels {
            guard peer.id != panel.id else { continue }
            candidates += getPeerAffinityCandidates(of: panel.rect, peer: peer)
        }
        candidates = candidates.filter { affinity, distance in
            switch affinity {
            case .root: distance < Self.rootAffinityThreshold
            case .peer: distance < Self.peerAffinityThreshold
            }
        }
        candidates = candidates.filter { affinity, _ in
            switch affinity {
            case .root: true
            case let .peer(peer):
                peer.selfAlign != .center && peer.peerAlign != .center || peer.selfAlign == .center && peer.peerAlign == .center
            }
        }
        let horizontal = candidates
            .filter { $0.affinity.axis == .horizontal }
            .max { $0.distance < $1.distance }
        let vertical = candidates
            .filter { $0.affinity.axis == .vertical }
            .max { $0.distance < $1.distance }
        return [horizontal, vertical].compactMap { $0?.affinity }
    }
}

// MARK: - offset by affinity

extension PanelModel {
    private func offset(of panel: PanelData, by affinity: PanelAffinity.Root) -> Vector2 {
        let axis = affinity.axis, align = affinity.align
        let kp = getKeyPath(axis: axis, align: align)

        var offset = rootRect[keyPath: kp] - panel.rect[keyPath: kp]
        offset += align == .start ? 12 : align == .end ? -12 : 0

        switch axis {
        case .horizontal: return .init(offset, 0)
        case .vertical: return .init(0, offset)
        }
    }

    private func offset(of panel: PanelData, by affinity: PanelAffinity.Peer) -> Vector2 {
        guard let peerPanel = idToPanel[affinity.peerId] else { return .zero }
        let axis = affinity.axis, selfAlign = affinity.selfAlign, peerAlign = affinity.peerAlign
        let panelKeyPath = getKeyPath(axis: axis, align: selfAlign)
        let peerKeyPath = getKeyPath(axis: axis, align: peerAlign)

        var offset = peerPanel.rect[keyPath: peerKeyPath] - panel.rect[keyPath: panelKeyPath]
        offset += selfAlign == peerAlign ? 0 : selfAlign == .start ? 6 : selfAlign == .end ? -6 : 0

        switch axis {
        case .horizontal: return .init(offset, 0)
        case .vertical: return .init(0, offset)
        }
    }

    private func offset(of panel: PanelData, by affinity: PanelAffinity) -> Vector2 {
        switch affinity {
        case let .root(root): offset(of: panel, by: root)
        case let .peer(peer): offset(of: panel, by: peer)
        }
    }

    func offsetByAffinities(of panel: PanelData) -> Vector2 {
        var sum = Vector2.zero
        for affinity in panel.affinities {
            sum += offset(of: panel, by: affinity)
        }
        return sum
    }
}
