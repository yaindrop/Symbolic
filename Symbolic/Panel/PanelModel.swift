import Foundation
import SwiftUI

private let subtracer = tracer.tagged("PanelModel")

// MARK: - PanelModel

class PanelModel: ObservableObject {
    @Published var idToPanel: [UUID: PanelData] = [:]
    @Published var panelIds: [UUID] = []
    @Published var rootSize: CGSize = .zero

    var panels: [PanelData] { panelIds.compactMap { idToPanel[$0] } }
    var rootRect: CGRect { .init(rootSize) }

    fileprivate var movingPanel: [UUID: PanelData] = [:]
}

extension PanelModel {
    func register(align: PlaneInnerAlign = .topLeading, @ViewBuilder _ panel: @escaping () -> any View) {
        var panelData = PanelData(view: AnyView(panel()))
        panelData.affinities += Axis.allCases.map { axis in .root(.init(axis: axis, align: align.getAxisInnerAlign(in: axis))) }
        idToPanel[panelData.id] = panelData
        panelIds.append(panelData.id)
    }

    func deregister(panelId: UUID) {
        idToPanel.removeValue(forKey: panelId)
        panelIds.removeAll { $0 == panelId }
    }
}

extension PanelModel {
    func onMoving(panelId: UUID, _ v: DragGesture.Value) {
        guard let origin = movingPanel[panelId]?.origin else { return }
        let offset = v.offset
        let _r = subtracer.range("moving \(panelId) from \(origin) by \(offset)", type: .intent); defer { _r() }
        guard var panel = idToPanel[panelId] else { return }
        panel.origin = origin + offset
        subtracer.instant("panel.origin \(panel.origin)")
        idToPanel[panelId] = panel
        if panelIds.last != panelId {
            panelIds.removeAll { $0.id == panelId }
            panelIds.append(panelId)
        }
    }

    func onMoved(panelId: UUID, _ v: DragGesture.Value) {
        guard let origin = movingPanel[panelId]?.origin else { return }
        let offset = v.offset, speed = v.speed
        let _r = subtracer.range("moved \(panelId) from \(origin) by \(offset) with speed \(speed)", type: .intent); defer { _r() }
        guard var panel = idToPanel[panelId] else { return }
        panel.origin = origin + offset
        idToPanel[panelId] = panel

        let newPanel = moveEndOffset(panel: panel, v)
        if panel.origin == newPanel.origin, panel.affinities == newPanel.affinities {
            return
        }

        withAnimation(.easeOut(duration: 0.1)) {
            idToPanel[panelId] = newPanel
        }
    }

    private func moveEndOffset(panel: PanelData, _ v: DragGesture.Value) -> PanelData {
        let offset = v.offset, speed = v.speed

        var inertiaOffset = Vector2.zero
        if speed.length > 500 {
            inertiaOffset = speed * 0.2
        }
        if inertiaOffset.length > offset.length * 2 {
            inertiaOffset = inertiaOffset.with(length: offset.length)
        }

        var newPanel = panel
        newPanel.origin += inertiaOffset
        subtracer.instant("inertiaOffset \(inertiaOffset)")

        let clampingOffset = newPanel.rect.clampingOffset(by: rootRect)
        newPanel.origin += clampingOffset
        subtracer.instant("clampingOffset \(clampingOffset)")

        newPanel.affinities = getAffinities(of: newPanel)

        let affinityOffset = affinityOffset(of: newPanel)
        newPanel.origin += affinityOffset
        subtracer.instant("affinityOffset \(affinityOffset)")

        return newPanel
    }

    func moveGesture(panelId: UUID) -> MultipleGesture {
        .init(
            configs: .init(coordinateSpace: .global),
            onPress: {
                guard let panel = self.idToPanel[panelId] else { return }
                self.movingPanel[panelId] = panel
            },
            onPressEnd: { _ in
                self.movingPanel[panelId] = nil
            },
            onDrag: {
                self.onMoving(panelId: panelId, $0)
            },
            onDragEnd: {
                self.onMoved(panelId: panelId, $0)
            }
        )
    }
}

extension PanelModel {
    func onResized(panelId: UUID, size: CGSize) {
        let _r = subtracer.range("resize \(panelId) to \(size)"); defer { _r() }
        guard var panel = idToPanel[panelId] else { return }
        panel.size = size
        panel.origin += affinityOffset(of: panel)
        withAnimation {
            idToPanel[panel.id] = panel
        }

        for (id, panel) in idToPanel {
            if panel.affinities.contains(where: { $0.related(to: panelId) }) {
                idToPanel[id]?.affinities = getAffinities(of: panel)
                idToPanel[id]?.origin += affinityOffset(of: panel)
            }
        }
    }

    func onRootResized(size: CGSize) {
        let _r = subtracer.range("resize root \(size)"); defer { _r() }
        rootSize = size
//        withAnimation {
        for id in panelIds {
            guard var panel = idToPanel[id] else { return }
            panel.origin += affinityOffset(of: panel)
            idToPanel[panel.id] = panel
        }
//        }
    }
}

// MARK: - get affinities

private func getKeyPath(axis: Axis, align: AxisInnerAlign) -> KeyPath<CGRect, Scalar> {
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
    static let rootAffinityThreshold = 32.0
    static let peerAffinityThreshold = 16.0
    static let rootAffinityGap = 12.0
    static let peerAffinityGap = 6.0

    typealias PanelAffinityCandidate = (affinity: PanelAffinity, distance: Scalar)
    private func getRootAffinityCandidates(of rect: CGRect) -> [PanelAffinityCandidate] {
        Axis.allCases.flatMap { axis in
            AxisInnerAlign.allCases.map { align in
                let kp = getKeyPath(axis: axis, align: align)
                let distance = abs(rect[keyPath: kp] - rootRect[keyPath: kp])
                return (.root(.init(axis: axis, align: align)), distance)
            }
        }
    }

    private func getPeerAffinityCandidates(of rect: CGRect, peer: PanelData) -> [PanelAffinityCandidate] {
        Axis.allCases.flatMap { axis in
            AxisInnerAlign.allCases.flatMap { selfAlign in
                AxisInnerAlign.allCases.map { peerAlign in
                    let selfKp = getKeyPath(axis: axis, align: selfAlign)
                    let peerKp = getKeyPath(axis: axis, align: peerAlign)
                    let distance = abs(rect[keyPath: selfKp] - peer.rect[keyPath: peerKp])
                    return (.peer(.init(peerId: peer.id, axis: axis, selfAlign: selfAlign, peerAlign: peerAlign)), distance)
                }
            }
        }
    }

    private func getAffinities(of panel: PanelData) -> [PanelAffinity] {
        func isValid(candidate: PanelAffinityCandidate) -> Bool {
            let (affinity, distance) = candidate
            var threshold: Scalar
            switch affinity {
            case .root: threshold = Self.rootAffinityThreshold
            case .peer: threshold = Self.peerAffinityThreshold
            }
            if distance > threshold {
                return false
            }

            if !rootRect.contains(panel.rect + offset(of: panel, by: affinity)) {
                return false
            }

            if case let .peer(peer) = affinity {
                return peer.selfAlign != .center && peer.peerAlign != .center || peer.selfAlign == .center && peer.peerAlign == .center
            }
            return true
        }

        var candidates = getRootAffinityCandidates(of: panel.rect)
        for peer in panels {
            guard peer.id != panel.id else { continue }
            candidates += getPeerAffinityCandidates(of: panel.rect, peer: peer)
        }
        candidates = candidates.filter { isValid(candidate: $0) }

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
        let axis = affinity.axis, align = affinity.align, keyPath = getKeyPath(axis: axis, align: align)

        var offset = rootRect[keyPath: keyPath] - panel.rect[keyPath: keyPath]
        offset += align == .start ? Self.rootAffinityGap : align == .end ? -Self.rootAffinityGap : 0

        return .init(axis: axis, offset)
    }

    private func offset(of panel: PanelData, by affinity: PanelAffinity.Peer) -> Vector2 {
        guard let peerPanel = idToPanel[affinity.peerId] else { return .zero }
        let axis = affinity.axis, selfAlign = affinity.selfAlign, peerAlign = affinity.peerAlign
        let panelKeyPath = getKeyPath(axis: axis, align: selfAlign), peerKeyPath = getKeyPath(axis: axis, align: peerAlign)

        var offset = peerPanel.rect[keyPath: peerKeyPath] - panel.rect[keyPath: panelKeyPath]
        offset += selfAlign == peerAlign ? 0 : selfAlign == .start ? Self.peerAffinityGap : selfAlign == .end ? -Self.peerAffinityGap : 0

        return .init(axis: axis, offset)
    }

    private func offset(of panel: PanelData, by affinity: PanelAffinity) -> Vector2 {
        switch affinity {
        case let .root(root): offset(of: panel, by: root)
        case let .peer(peer): offset(of: panel, by: peer)
        }
    }

    func affinityOffset(of panel: PanelData) -> Vector2 {
        var sum = Vector2.zero
        sum += panel.affinities.first { $0.axis == .horizontal }.map { offset(of: panel, by: $0) } ?? .zero
        sum += panel.affinities.first { $0.axis == .vertical }.map { offset(of: panel, by: $0) } ?? .zero
        return sum
    }
}
