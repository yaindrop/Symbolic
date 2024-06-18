import SwiftUI

private let subtracer = tracer.tagged("PanelStore")

typealias PanelMap = OrderedMap<UUID, PanelData>

// MARK: - PanelStore

class PanelStore: Store {
    @Trackable var panelMap = PanelMap()
    @Trackable var rootRect: CGRect = .zero

    @Trackable var movingPanelMap: [UUID: MovingPanelData] = [:]

    @Trackable var sidebarFrame: CGRect = .zero
    @Trackable var sidebarPanelIds: Set<UUID> = []
}

private extension PanelStore {
    func update(panelMap: PanelMap) {
        update { $0(\._panelMap, panelMap) }
    }

    func update(rootRect: CGRect) {
        update { $0(\._rootRect, rootRect) }
    }

    func update(movingPanelMap: [UUID: MovingPanelData]) {
        update { $0(\._movingPanelMap, movingPanelMap) }
    }
}

extension PanelStore {
    func update(sidebarFrame: CGRect) {
        update { $0(\._sidebarFrame, sidebarFrame) }
    }

    func update(sidebarPanelIds: Set<UUID>) {
        update { $0(\._sidebarPanelIds, sidebarPanelIds) }
    }

    func drop(panelId: UUID, location: Point2) {
        guard var panel = get(id: panelId) else { return }
        withStoreUpdating {
            update(sidebarPanelIds: sidebarPanelIds.cloned { $0.remove(panelId) })

            panel.align = .topLeading
            let offset = Vector2(location) - .init(panel.size) / 2
            let moveTarget = moveTarget(moving: .init(data: panel, globalPosition: location, offset: offset), speed: .zero)
            panel.align = moveTarget.align
            update(panelMap: panelMap.cloned {
                $0.removeValue(forKey: panelId)
                $0[panelId] = panel
            })
        }
    }
}

// MARK: selectors

extension PanelStore {
    func get(id: UUID) -> PanelData? { panelMap.value(key: id) }
    func moving(id: UUID) -> MovingPanelData? { movingPanelMap.value(key: id) }

    var panels: [PanelData] { panelMap.values }

    var panelIds: [UUID] { panelMap.keys }

    var floatingPanelIds: [UUID] { panelIds.filter { !sidebarPanelIds.contains($0) } }
    var floatingPanels: [PanelData] { floatingPanelIds.compactMap { get(id: $0) } }

    var sidebarPanels: [PanelData] { panels.filter { sidebarPanelIds.contains($0.id) } }

    func appearance(id: UUID) -> PanelAppearance {
        guard let panel = get(id: id) else { return .floatingHidden }
        guard floatingPanelIds.contains(id) else { return .sidebarSection }
        let peers = floatingPanels.filter { $0.align == panel.align }
        if peers.last?.id == id {
            return .floatingPrimary
        } else if peers.dropLast().last?.id == id {
            return .floatingSecondary
        }
        return .floatingHidden
    }
}

// MARK: actions

extension PanelStore {
    func register(align: PlaneInnerAlign = .topLeading, @ViewBuilder _ panel: @escaping () -> any View) {
        let panel = PanelData(view: AnyView(panel()))
        update(panelMap: panelMap.cloned { $0[panel.id] = panel })
    }

    func deregister(panelId: UUID) {
        update(panelMap: panelMap.cloned { $0.removeValue(forKey: panelId) })
    }
}

// MARK: moving

extension PanelStore {
    func spin(on panelId: UUID) {
        guard let panel = get(id: panelId) else { return }
        guard appearance(id: panelId) == .floatingSecondary else { return }
        let peers = panelMap.values.filter { $0.align == panel.align }
        guard let primary = peers.last else { return }
        update(panelMap: panelMap.cloned {
            $0.removeValue(forKey: primary.id)
            $0.insert((primary.id, primary), at: 0)
        })
    }

    func onMoving(panelId: UUID, _ v: DragGesture.Value) {
        let _r = subtracer.range(type: .intent, "moving \(panelId) by \(v.offset)"); defer { _r() }
        var moving: MovingPanelData
        let prev = self.moving(id: panelId)
        if let prev, prev.endTask == nil {
            moving = prev
            moving.globalPosition = v.location
            moving.offset = v.offset
        } else {
            prev?.endTask?.cancel()
            guard let panel = get(id: panelId) else { return }
            moving = .init(data: panel, globalPosition: v.location, offset: v.offset)
        }

        let moveTarget = moveTarget(moving: moving, speed: .zero)
        moving.align = moveTarget.align
        moving.offset = moveTarget.offset
        withStoreUpdating {
            update(panelMap: panelMap.cloned {
                $0.removeValue(forKey: panelId)
                $0[panelId] = moving.data.cloned { $0.align = moveTarget.align }
            })
            update(movingPanelMap: movingPanelMap.cloned { $0[panelId] = moving })
        }
    }

    func onMoved(panelId: UUID, _ v: DragGesture.Value) {
        guard var moving = moving(id: panelId) else { return }
        moving.globalPosition = v.location
        moving.offset = v.offset

        let _r = subtracer.range(type: .intent, "moved \(panelId) by \(v.offset) with speed \(v.speed)"); defer { _r() }
        if sidebarFrame.contains(moving.globalPosition) {
            withStoreUpdating {
                update(sidebarPanelIds: sidebarPanelIds.cloned { $0.insert(panelId) })
                update(movingPanelMap: self.movingPanelMap.cloned { $0[panelId] = nil })
            }
            return
        }

        let moveTarget = moveTarget(moving: moving, speed: v.speed)
        moving.align = moveTarget.align
        moving.offset = moveTarget.offset
        withStoreUpdating {
            update(panelMap: panelMap.cloned { $0[panelId] = moving.data.cloned { $0.align = moveTarget.align } })
            update(movingPanelMap: movingPanelMap.cloned { $0[panelId] = moving })
        }

        var target = moving
        target.offset = .zero
        target.endTask = Task { @MainActor in
            try await Task.sleep(for: .seconds(0.5))
            withAnimation(.fast) {
                self.update(movingPanelMap: self.movingPanelMap.cloned { $0[panelId] = nil })
            }
        }

        Task { @MainActor [target] in
            withAnimation(.spring(duration: 0.5)) {
                update(movingPanelMap: movingPanelMap.cloned { $0[panelId] = target })
            }
        }
    }

    func rect(of panel: PanelData) -> CGRect {
        rootRect.alignedBox(at: panel.align, size: panel.size, gap: .init(12, 24))
    }

    func rect(of moving: MovingPanelData) -> CGRect {
        rect(of: moving.data) + moving.offset
    }

    private func moveTarget(moving: MovingPanelData, speed: Vector2) -> (offset: Vector2, align: PlaneInnerAlign) {
        var inertiaOffset = Vector2.zero
        if speed.length > 400 {
            inertiaOffset = speed / 4
        }
        if inertiaOffset.length > moving.offset.length * 2 {
            inertiaOffset = inertiaOffset.with(length: moving.offset.length)
        }
        subtracer.instant("inertiaOffset \(inertiaOffset) \(rect(of: moving) + inertiaOffset) \(rootRect)")

        let clampingOffset = (rect(of: moving) + inertiaOffset).clampingOffset(by: rootRect)
        subtracer.instant("clampingOffset \(clampingOffset)")

        let clamped = rect(of: moving) + inertiaOffset + clampingOffset
        let align = rootRect.nearestInnerAlign(of: clamped.center, isCorner: true)
        subtracer.instant("align \(align)")

        let aligned = moving.data.cloned { $0.align = align }
        let alignOffset = rect(of: aligned).origin.offset(to: rect(of: moving).origin)
        subtracer.instant("alignOffset \(alignOffset), \(rect(of: aligned)), \(rect(of: moving))")

        return (alignOffset, align)
    }

    func moveGesture(panelId: UUID) -> MultipleGesture? {
        if sidebarPanelIds.contains(panelId) {
            return nil
        }
        return .init(
            configs: .init(coordinateSpace: .global),
            onPressEnd: { cancelled in
                if cancelled {
                    self.update(movingPanelMap: self.movingPanelMap.cloned { $0[panelId] = nil })
                }
            },
            onTap: { _ in
                self.spin(on: panelId)
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
        guard let panel = get(id: panelId) else { return }
        withAnimation(.fast) {
            update(panelMap: panelMap.cloned { $0[panel.id] = panel.cloned { $0.size = size } })
        }
    }

    func setRootRect(_ rect: CGRect) {
        let _r = subtracer.range("set root rect \(rect)"); defer { _r() }

        withAnimation(.fast) {
            update(rootRect: rect)
        }
    }
}
