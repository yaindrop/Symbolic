import SwiftUI

private let subtracer = tracer.tagged("PanelStore")

typealias PanelMap = OrderedMap<UUID, PanelData>

// MARK: - PanelStore

class PanelStore: Store {
    @Trackable var panelMap = PanelMap()
    @Trackable var rootRect: CGRect = .zero

    @Trackable var movingPanel: [UUID: MovingPanelData] = [:]

    @Trackable var sidebarFrame: CGRect = .zero
    @Trackable var sidebarPanels: [UUID] = []
}

private extension PanelStore {
    func update(panelMap: PanelMap) {
        update { $0(\._panelMap, panelMap) }
    }

    func update(rootRect: CGRect) {
        update { $0(\._rootRect, rootRect) }
    }

    func update(movingPanel: [UUID: MovingPanelData]) {
        update { $0(\._movingPanel, movingPanel) }
    }
}

extension PanelStore {
    func update(sidebarFrame: CGRect) {
        update { $0(\._sidebarFrame, sidebarFrame) }
    }

    func update(sidebarPanels: [UUID]) {
        update { $0(\._sidebarPanels, sidebarPanels) }
    }

    func drop(panelId: UUID, location _: Point2) {
        guard var panel = get(id: panelId) else { return }
        withStoreUpdating {
            update(sidebarPanels: sidebarPanels.with { $0.removeAll { $0 == panelId }})
//            panel.origin = location - .init(panel.size.width / 2, 0)
//            panel = moveEndOffset(panel: panel, offset: .zero, speed: .zero)
            var panelMap = panelMap
            panelMap[panelId] = panel
            update(panelMap: panelMap)
        }
    }
}

// MARK: selectors

extension PanelStore {
    var panels: [PanelData] { panelMap.values }
//    var rootRect: CGRect { .init(rootSize) }

    var panelIds: [UUID] { panelMap.keys }
    var floatingPanelIds: [UUID] { panelIds.filter { id in !sidebarPanels.contains { $0 == id }}}

    func get(id: UUID) -> PanelData? { panelMap.value(key: id) }

    func moving(id: UUID) -> MovingPanelData? { movingPanel.value(key: id) }
}

// MARK: actions

extension PanelStore {
    func register(align: PlaneInnerAlign = .topLeading, @ViewBuilder _ panel: @escaping (_ panelId: UUID) -> any View) {
        var panelData = PanelData(view: { AnyView(panel($0)) })
//        for axis in Axis.allCases {
//            panelData.affinities[axis] = .root(.init(axis: axis, align: align[axis]))
//        }

        var updated = panelMap
        updated[panelData.id] = panelData
        update(panelMap: updated)
    }

    func deregister(panelId: UUID) {
        var updated = panelMap
        updated.removeValue(forKey: panelId)
        update(panelMap: updated)
    }
}

// MARK: moving

extension PanelStore {
    func onMoving(panelId: UUID, _ v: DragGesture.Value) {
        let _r = subtracer.range(type: .intent, "moving \(panelId) by \(v.offset)"); defer { _r() }
        if let moving = movingPanel.value(key: panelId) {
            var movingPanel = self.movingPanel
            movingPanel[panelId] = .init(data: moving.data, globalPosition: v.location, offset: v.offset)
            update(movingPanel: movingPanel)
        } else {
            guard let panel = get(id: panelId) else { return }
            var movingPanel = self.movingPanel
            movingPanel[panelId] = .init(data: panel, globalPosition: v.location, offset: v.offset)
            update(movingPanel: movingPanel)
        }
    }

    func onMoved(panelId: UUID, _ v: DragGesture.Value) {
        guard var moving = movingPanel.value(key: panelId) else { return }
        moving.offset = v.offset

        let _r = subtracer.range(type: .intent, "moved \(panelId) by \(v.offset) with speed \(v.speed)"); defer { _r() }
        if sidebarFrame.contains(moving.globalPosition) {
            update(sidebarPanels: sidebarPanels.with { $0.append(panelId) })
            return
        }

        var movingPanel = self.movingPanel
        movingPanel[panelId] = moving
        update(movingPanel: movingPanel)

        let moveEndOffset = moveEndOffset(moving: moving, speed: v.speed)

//        let movePanel = panel
        Task { @MainActor in
            withAnimation {
                var movingPanel = self.movingPanel
                movingPanel[panelId]?.offset = moveEndOffset
                update(movingPanel: movingPanel)
            } completion: {
                var movingPanel = self.movingPanel
                movingPanel[panelId] = nil
                self.update(movingPanel: movingPanel)
            }
//            let newPanel = moveEndOffset(panel: movePanel, offset: v.offset, speed: v.speed)
//            if movePanel.origin == newPanel.origin, movePanel.affinities == newPanel.affinities {
//                return
//            }
//
//            withAnimation(.easeOut(duration: 0.1)) {
//                let _r = subtracer.range(type: .intent, "withAnimation easeOut"); defer { _r() }
//
//                var updated = panelMap
//                updated[panelId] = newPanel
//                update(panelMap: updated)
//            } completion: {}
        }
    }

    func rect(of panel: PanelData) -> CGRect {
        rootRect.alignedBox(at: panel.align, size: panel.size, gap: .init(squared: 12))
    }

    func rect(of moving: MovingPanelData) -> CGRect {
        rect(of: moving.data) + moving.offset
    }

    private func moveEndOffset(moving: MovingPanelData, speed: Vector2) -> Vector2 {
        var inertiaOffset = Vector2.zero
        if speed.length > 500 {
            inertiaOffset = speed * 0.2
        }
        if inertiaOffset.length > moving.offset.length * 2 {
            inertiaOffset = inertiaOffset.with(length: moving.offset.length)
        }
        subtracer.instant("inertiaOffset \(inertiaOffset) \(rect(of: moving) + inertiaOffset) \(rootRect)")

        let clampingOffset = (rect(of: moving) + inertiaOffset).clampingOffset(by: rootRect)
        subtracer.instant("clampingOffset \(clampingOffset)")

        return moving.offset + inertiaOffset + clampingOffset
    }

    func moveGesture(panelId: UUID) -> MultipleGesture? {
        if sidebarPanels.contains(where: { $0 == panelId }) {
            return nil
        }
        return .init(
            configs: .init(coordinateSpace: .global),
            onPressEnd: { _ in
//                var movingPanel = self.movingPanel
//                movingPanel[panelId] = nil
//                self.update(movingPanel: movingPanel)
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

// MARK: resizing

extension PanelStore {
    func onResized(panelId: UUID, size: CGSize) {
        let _r = subtracer.range("resize \(panelId) to \(size)"); defer { _r() }
        guard var panel = get(id: panelId) else { return }
        panel.size = size
//        panel.origin += affinityOffset(of: panel)
//        subtracer.instant("panel.origin \(panel.origin)")
//
        var updated = panelMap
        updated[panel.id] = panel
//
//        for panel in panels {
//            if panel.affinities.related(to: panelId) {
//                var panel = panel
//                panel.affinities = getAffinities(of: panel)
//                panel.origin += affinityOffset(of: panel)
//                updated[panel.id] = panel
//                subtracer.instant("panel \(panel.id) origin \(panel.origin)")
//            }
//        }
//
        withAnimation(.fast) {
            update(panelMap: updated)
        }
    }

    func setRootRect(_ rect: CGRect) {
        let _r = subtracer.range("set root rect \(rect)"); defer { _r() }

        withAnimation(.fast) {
            withStoreUpdating {
                update(rootRect: rect)

//                var updated = panelMap
//                for var panel in panels {
//                    panel.origin += affinityOffset(of: panel)
//                    updated[panel.id] = panel
//                }
//
//                update(panelMap: updated)
            }
        }
    }
}

// MARK: - get affinities

// extension PanelStore {
//    static let rootAffinityThreshold = 32.0
//    static let peerAffinityThreshold = 16.0
//    static let rootAffinityGap = 12.0
//    static let peerAffinityGap = 6.0
//
//    typealias PanelAffinityCandidate = (affinity: PanelAffinity, distance: Scalar)
//    private func getRootAffinityCandidates(of rect: CGRect) -> [PanelAffinityCandidate] {
//        Axis.allCases.flatMap { axis in
//            AxisAlign.allCases.map { align in
//                let kp = CGRect.keyPath(on: axis, align: align)
//                let distance = abs(rect[keyPath: kp] - rootRect[keyPath: kp])
//                return (.root(.init(axis: axis, align: align)), distance)
//            }
//        }
//    }
//
//    private func getPeerAffinityCandidates(of rect: CGRect, peer: PanelData) -> [PanelAffinityCandidate] {
//        Axis.allCases.flatMap { axis in
//            AxisAlign.allCases.flatMap { selfAlign in
//                AxisAlign.allCases.map { peerAlign in
//                    let selfKp = CGRect.keyPath(on: axis, align: selfAlign)
//                    let peerKp = CGRect.keyPath(on: axis, align: peerAlign)
//                    let distance = abs(rect[keyPath: selfKp] - peer.rect[keyPath: peerKp])
//                    return (.peer(.init(peerId: peer.id, axis: axis, selfAlign: selfAlign, peerAlign: peerAlign)), distance)
//                }
//            }
//        }
//    }
//
//    private func getAffinities(of panel: PanelData) -> PanelAffinityPair {
//        func isValid(candidate: PanelAffinityCandidate) -> Bool {
//            let (affinity, distance) = candidate
//            var threshold: Scalar
//            switch affinity {
//            case .root: threshold = Self.rootAffinityThreshold
//            case .peer: threshold = Self.peerAffinityThreshold
//            }
//            if distance > threshold {
//                return false
//            }
//
//            if !rootRect.contains(panel.rect + offset(of: panel, by: affinity)) {
//                return false
//            }
//
//            if case let .peer(peer) = affinity {
//                return peer.selfAlign != .center && peer.peerAlign != .center || peer.selfAlign == .center && peer.peerAlign == .center
//            }
//            return true
//        }
//
//        var candidates = getRootAffinityCandidates(of: panel.rect)
//        for peer in panels {
//            guard peer.id != panel.id else { continue }
//            candidates += getPeerAffinityCandidates(of: panel.rect, peer: peer)
//        }
//        candidates = candidates.filter { isValid(candidate: $0) }
//
//        let horizontal = candidates
//            .filter { $0.affinity.axis == .horizontal }
//            .max { $0.distance < $1.distance }
//        let vertical = candidates
//            .filter { $0.affinity.axis == .vertical }
//            .max { $0.distance < $1.distance }
//        return .init(horizontal: horizontal?.affinity, vertical: vertical?.affinity)
//    }
// }

// MARK: - offset by affinity

// extension PanelStore {
//    private func offset(of panel: PanelData, by affinity: PanelAffinity.Root) -> Vector2 {
//        let axis = affinity.axis, align = affinity.align, keyPath = CGRect.keyPath(on: axis, align: align)
//
//        var offset = rootRect[keyPath: keyPath] - panel.rect[keyPath: keyPath]
//        offset += align == .start ? Self.rootAffinityGap : align == .end ? -Self.rootAffinityGap : 0
//
//        return .init(axis: axis, offset)
//    }
//
//    private func offset(of panel: PanelData, by affinity: PanelAffinity.Peer) -> Vector2 {
//        guard let peerPanel = self.panel(id: affinity.peerId) else { return .zero }
//        let axis = affinity.axis, selfAlign = affinity.selfAlign, peerAlign = affinity.peerAlign
//        let panelKeyPath = CGRect.keyPath(on: axis, align: selfAlign), peerKeyPath = CGRect.keyPath(on: axis, align: peerAlign)
//
//        var offset = peerPanel.rect[keyPath: peerKeyPath] - panel.rect[keyPath: panelKeyPath]
//        offset += selfAlign == peerAlign ? 0 : selfAlign == .start ? Self.peerAffinityGap : selfAlign == .end ? -Self.peerAffinityGap : 0
//
//        return .init(axis: axis, offset)
//    }
//
//    private func offset(of panel: PanelData, by affinity: PanelAffinity) -> Vector2 {
//        switch affinity {
//        case let .root(root): offset(of: panel, by: root)
//        case let .peer(peer): offset(of: panel, by: peer)
//        }
//    }
//
//    private func affinityOffset(of panel: PanelData) -> Vector2 {
//        Axis.allCases.reduce(into: .zero) {
//            $0 += panel.affinities[$1].map { offset(of: panel, by: $0) } ?? .zero
//        }
//    }
// }
