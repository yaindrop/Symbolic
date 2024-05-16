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
    func register(align: PlaneAlign = .topLeading, @ViewBuilder _ panel: @escaping () -> any View) {
        var panelData = PanelData(view: AnyView(panel()))
        panelData.affinities += Axis.allCases.map { axis in .root(.init(axis: axis, align: align.getAxisAlign(in: axis))) }
        idToPanel[panelData.id] = panelData
        panelIds.append(panelData.id)
    }

    func deregister(panelId: UUID) {
        idToPanel.removeValue(forKey: panelId)
        panelIds.removeAll { $0 == panelId }
    }
}

extension PanelModel {
    func onMoving(panelId: UUID, origin: Point2, _ v: DragGesture.Value) {
        let offset = v.offset
        let _r = tracer.range("[panel] moving \(panelId) from \(origin) by \(offset)", type: .intent); defer { _r() }
        guard var panel = idToPanel[panelId] else { return }
        panel.origin = origin + offset
        panel.origin += panel.rect.clampingOffset(by: rootRect)
        idToPanel[panelId] = panel
        if panelIds.last != panelId {
            panelIds.removeAll { $0.id == panelId }
            panelIds.append(panelId)
        }
    }

    func onMoved(panelId: UUID, origin: Point2, _ v: DragGesture.Value) {
        let offset = v.offset, speed = v.speed
        let _r = tracer.range("[panel] moved \(panelId) from \(origin) by \(offset) with speed \(speed)", type: .intent); defer { _r() }
        guard var panel = idToPanel[panelId] else { return }
        panel.origin = origin + offset
        panel.origin += panel.rect.clampingOffset(by: rootRect)
        idToPanel[panelId] = panel

        let inertiaDuration: TimeInterval = 0.1
        var inertia = speed * inertiaDuration
        if inertia.length > offset.length {
            inertia = inertia.with(length: offset.length)
        }

        // TODO: prioritize clamp over affinity
        panel.origin += inertia
        let clamping = panel.rect.clampingOffset(by: rootRect)
        panel.origin += clamping

        panel.affinities = getAffinities(of: panel)
        panel.origin += affinityOffset(of: panel)

        if panel.origin == origin + offset {
            return
        }

        withAnimation(.easeOut(duration: inertiaDuration)) {
            idToPanel[panelId] = panel
        }
    }

    static func moveGestureModel() -> MultipleGestureModel<PanelData?> { .init(configs: .init(coordinateSpace: .global)) }

    var moveGestureSetup: (MultipleGestureModel<PanelData?>) -> Void {
        {
            $0.onDrag { v, panel in
                guard let panel else { return }
                self.onMoving(panelId: panel.id, origin: panel.origin, v)
            }
            $0.onDragEnd { v, panel in
                guard let panel else { return }
                self.onMoved(panelId: panel.id, origin: panel.origin, v)
            }
        }
    }
}

extension PanelModel {
    func onResized(panelId: UUID, size: CGSize) {
        let _r = tracer.range("[panel] resize \(panelId) to \(size)"); defer { _r() }
        guard var panel = idToPanel[panelId] else { return }
        panel.size = size
        panel.origin += affinityOffset(of: panel)
        withAnimation {
            idToPanel[panel.id] = panel
        }
    }

    func onRootResized(size: CGSize) {
        let _r = tracer.range("[panel] resize root \(size)"); defer { _r() }
        rootSize = size
        withAnimation {
            for id in panelIds {
                guard var panel = idToPanel[id] else { return }
                panel.origin += affinityOffset(of: panel)
                idToPanel[panel.id] = panel
            }
        }
    }
}

// MARK: - get affinities

fileprivate func getKeyPath(axis: Axis, align: AxisAlign) -> KeyPath<CGRect, Scalar> {
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
    static let rootAffinityThreshold = 48.0
    static let peerAffinityThreshold = 24.0
    static let rootAffinityGap = 12.0
    static let peerAffinityGap = 6.0

    typealias PanelAffinityCandidate = (affinity: PanelAffinity, distance: Scalar)
    private func getRootAffinityCandidates(of rect: CGRect) -> [PanelAffinityCandidate] {
        Axis.allCases.flatMap { axis in
            AxisAlign.allCases.map { align in
                let kp = getKeyPath(axis: axis, align: align)
                let distance = abs(rect[keyPath: kp] - rootRect[keyPath: kp])
                return (.root(.init(axis: axis, align: align)), distance)
            }
        }
    }

    private func getPeerAffinityCandidates(of rect: CGRect, peer: PanelData) -> [PanelAffinityCandidate] {
        Axis.allCases.flatMap { axis in
            AxisAlign.allCases.flatMap { selfAlign in
                AxisAlign.allCases.map { peerAlign in
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
        offset += align == .start ? Self.rootAffinityGap : align == .end ? -Self.rootAffinityGap : 0

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
        offset += selfAlign == peerAlign ? 0 : selfAlign == .start ? Self.peerAffinityGap : selfAlign == .end ? -Self.peerAffinityGap : 0

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

    func affinityOffset(of panel: PanelData) -> Vector2 {
        var sum = Vector2.zero
        for affinity in panel.affinities {
            sum += offset(of: panel, by: affinity)
        }
        return sum
    }
}
