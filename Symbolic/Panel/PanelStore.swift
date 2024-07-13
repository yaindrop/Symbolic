import SwiftUI

private let subtracer = tracer.tagged("PanelStore")

typealias PanelMap = OrderedMap<UUID, PanelData>

// MARK: - PanelStore

class PanelStore: Store {
    @Trackable var panelMap = PanelMap()
    @Trackable var movingPanelMap: [UUID: MovingPanelData] = [:]

    @Trackable var rootFrame: CGRect = .zero
    @Trackable var panelFrameMap: [UUID: CGRect] = [:]

    @Trackable var popoverActive: Bool = false
    @Trackable var popoverButtonFrame: CGRect = .zero
    @Trackable var popoverPanelIds: Set<UUID> = []

    @Derived({ $0.calcStyleMap }) var styleMap
}

private extension PanelStore {
    var calcStyleMap: [UUID: PanelStyle] {
        let alignMap = panelMap.values.reduce(into: [UUID: PlaneInnerAlign]()) { dict, panel in
            dict[panel.id] = moving(id: panel.id)?.align ?? panel.align
        }

        let squeezedMap = panelMap.keys.reduce(into: [UUID: Bool]()) { dict, id in
            dict[id] = {
                let floatingPanelIds = floatingPanelIds, floatingPanels = floatingPanels

                guard floatingPanelIds.contains(id) else { return false }
                guard let align = alignMap[id] else { return false }
                let neighborAlign = PlaneInnerAlign(horizontal: align.horizontal, vertical: align.vertical.flipped)

                let front = floatingPanels.last { alignMap[$0.id] == align }
                guard let front else { return false }

                let index = floatingPanelIds.firstIndex { $0 == front.id }
                guard let index else { return false }

                let neighbor = floatingPanels.last { alignMap[$0.id] == neighborAlign }
                guard let neighbor else { return false }

                let neighborIndex = floatingPanelIds.firstIndex { $0 == neighbor.id }
                guard let neighborIndex, neighborIndex > index else { return false }

                guard let frontFrame = panelFrameMap.value(key: front.id), let neighborFrame = panelFrameMap.value(key: neighbor.id) else { return false }
                return frontFrame.height + neighborFrame.height + floatingPanelSafeArea * 2 > rootFrame.height
            }()
        }

        let appearanceMap = panelMap.keys.reduce(into: [UUID: PanelAppearance]()) { dict, id in
            dict[id] = {
                if popoverPanelIds.contains(id) {
                    return .popoverSection
                }
                guard let align = alignMap[id] else { return .floatingPrimary }
                let peers = floatingPanels.filter { alignMap[$0.id] == align }
                let squeezed = squeezedMap[id] ?? false
                if peers.last?.id == id {
                    return squeezed ? .floatingSecondary : .floatingPrimary
                } else {
                    return peers.dropLast().last?.id == id && !squeezed ? .floatingSecondary : .floatingHidden
                }
            }()
        }

        let paddingMap = panelMap.keys.reduce(into: [UUID: CGSize]()) { dict, id in
            dict[id] = {
                guard moving(id: id) == nil else { return floatingPanelPadding }
                let squeezed = squeezedMap[id] ?? false
                guard !squeezed else { return floatingPanelPaddingLarge }
                let align = alignMap[id]
                let peers = floatingPanels.filter { alignMap[$0.id] == align }
                return peers.count > 1 ? floatingPanelPaddingLarge : floatingPanelPadding
            }()
        }

        let maxHeightMap = panelMap.values.reduce(into: [UUID: Scalar]()) { dict, panel in
            dict[panel.id] = min(panel.maxHeight, floatingMaxHeight)
        }

        return panelMap.keys.reduce(into: [UUID: PanelStyle]()) { dict, id in
            dict[id] = .init(
                appearance: appearanceMap[id] ?? .floatingPrimary,
                squeezed: squeezedMap[id] ?? false,
                padding: paddingMap[id] ?? .zero,
                align: alignMap[id] ?? .topLeading,
                maxHeight: maxHeightMap[id] ?? floatingMaxHeight
            )
        }
    }
}

private extension PanelStore {
    func update(panelMap: PanelMap) {
        update { $0(\._panelMap, panelMap) }
    }

    func update(rootFrame: CGRect) {
        update { $0(\._rootFrame, rootFrame) }
    }

    func update(movingPanelMap: [UUID: MovingPanelData]) {
        update { $0(\._movingPanelMap, movingPanelMap) }
    }

    func update(panelFrameMap: [UUID: CGRect]) {
        update { $0(\._panelFrameMap, panelFrameMap) }
    }

    func update(popoverActive: Bool) {
        update { $0(\._popoverActive, popoverActive) }
    }

    func update(popoverButtonFrame: CGRect) {
        update { $0(\._popoverButtonFrame, popoverButtonFrame) }
    }

    func update(popoverPanelIds: Set<UUID>) {
        update { $0(\._popoverPanelIds, popoverPanelIds) }
    }
}

// MARK: selectors

extension PanelStore {
    var floatingPanelWidth: Scalar { 320 }

    var floatingPanelMinHeight: Scalar { 240 }

    var floatingPanelPadding: CGSize { .init(squared: 12) }

    var floatingPanelPaddingLarge: CGSize { .init(squared: 24) }

    var floatingPanelSafeArea: Scalar { 36 }

    var floatingMaxHeight: Scalar { rootFrame.height - floatingPanelSafeArea * 2 }
}

extension PanelStore {
    func get(id: UUID) -> PanelData? { panelMap.value(key: id) }
    func moving(id: UUID) -> MovingPanelData? { movingPanelMap.value(key: id) }
    func style(id: UUID) -> PanelStyle? { styleMap.value(key: id) }

    var panelIds: [UUID] { panelMap.keys }
    var panels: [PanelData] { panelMap.values }
}

extension PanelStore {
    var floatingPanelIds: [UUID] { panelIds.filter { !popoverPanelIds.contains($0) } }
    var floatingPanels: [PanelData] { floatingPanelIds.compactMap { get(id: $0) } }
}

extension PanelStore {
    var popoverPanels: [PanelData] { panels.filter { popoverPanelIds.contains($0.id) } }

    var popoverButtonHovering: Bool {
        movingPanelMap.contains { popoverButtonFrame.contains($0.value.globalDragPosition) }
    }
}

// MARK: actions

extension PanelStore {
    func register(name: String, align: PlaneInnerAlign = .topLeading, @ViewBuilder _ panel: @escaping () -> any View) {
        let panel = PanelData(name: name, view: AnyView(panel()), align: align)
        update(panelMap: panelMap.cloned { $0[panel.id] = panel })
    }

    func deregister(panelId: UUID) {
        update(panelMap: panelMap.cloned { $0.removeValue(forKey: panelId) })
    }

    func clear() {
        update(panelMap: [:])
    }
}

private extension PanelStore {
    func focus(panelId: UUID) {
        update(panelMap: panelMap.cloned { $0[panelId] = $0.removeValue(forKey: panelId) })
    }
}

extension PanelStore {
    func togglePopover() {
        update(popoverActive: !popoverActive)
    }

    func setPopoverButtonFrame(_ frame: CGRect) {
        update(popoverButtonFrame: frame)
    }

    func setFloating(panelId: UUID) {
        withStoreUpdating {
            update(popoverPanelIds: popoverPanelIds.cloned { $0.remove(panelId) })
            update(panelMap: panelMap.cloned { $0[panelId]?.align = .topTrailing })
            update(popoverActive: false)
        }
    }
}

// MARK: moving

extension PanelStore {
    func tap(on panelId: UUID) {
        guard let style = styleMap.value(key: panelId) else { return }
        guard style.appearance == .floatingSecondary else { return }
        if style.squeezed {
            focus(panelId: panelId)
        } else {
            let peers = panelMap.values.filter { styleMap.value(key: $0.id)?.align == style.align }
            guard let primary = peers.last, let secondary = peers.dropLast().last else { return }
            update(panelMap: panelMap.cloned {
                $0.removeValue(forKey: primary.id)
                $0.removeValue(forKey: secondary.id)
                $0.insert((primary.id, primary), at: 0)
                $0.append((secondary.id, secondary))
            })
        }
    }

    func onMoving(panelId: UUID, _ v: DragGesture.Value) {
        let _r = subtracer.range(type: .intent, "moving \(panelId) by \(v.offset)"); defer { _r() }
        var moving: MovingPanelData
        if let prev = self.moving(id: panelId) {
            moving = prev
            moving.globalDragPosition = v.location
            moving.offset = v.offset
        } else {
            guard let panel = get(id: panelId) else { return }
            moving = .init(id: panelId, globalDragPosition: v.location, offset: v.offset, align: panel.align)
        }

        let moveTarget = moveTarget(moving: moving, speed: .zero)
        moving.align = moveTarget.align
        moving.offset = moveTarget.offset
        withStoreUpdating {
            update(popoverActive: false)
            focus(panelId: panelId)
            update(movingPanelMap: movingPanelMap.cloned { $0[panelId] = moving })
        }
    }

    func onMoved(panelId: UUID, _ v: DragGesture.Value) {
        guard let panel = get(id: panelId) else { return }
        guard var moving = moving(id: panelId) else { return }
        moving.globalDragPosition = v.location
        moving.offset = v.offset

        let _r = subtracer.range(type: .intent, "moved \(panelId) by \(v.offset) with speed \(v.speed)"); defer { _r() }
        if popoverButtonFrame.contains(moving.globalDragPosition) {
            withStoreUpdating {
                update(popoverPanelIds: popoverPanelIds.cloned { $0.insert(panelId) })
                update(movingPanelMap: self.movingPanelMap.cloned { $0[panelId] = nil })
            }
            return
        }

        let moveTarget = moveTarget(moving: moving, speed: v.speed)
        moving.align = moveTarget.align
        moving.offset = moveTarget.offset
        moving.ended = true
        withStoreUpdating(configs: .init(syncNotify: true)) {
            update(panelMap: panelMap.cloned { $0[panelId] = panel.cloned { $0.align = moveTarget.align } })
            update(movingPanelMap: movingPanelMap.cloned { $0[panelId] = moving })
        }
    }

    func resetMoving(panelId: UUID) {
        withStoreUpdating(configs: .init(animation: .custom(.spring(duration: 0.5)))) {
            global.panel.update(movingPanelMap: global.panel.movingPanelMap.cloned { $0.removeValue(forKey: panelId) })
        }
    }

    func rect(of panel: PanelData) -> CGRect {
        let size = panelFrameMap.value(key: panel.id)?.size ?? .zero
        return rootFrame.alignedBox(at: panel.align, size: size, gap: floatingPanelPadding)
    }

    func rect(of moving: MovingPanelData) -> CGRect {
        guard let panel = get(id: moving.id) else { return .zero }
        return rect(of: panel) + moving.offset
    }

    private func moveTarget(moving: MovingPanelData, speed: Vector2) -> (offset: Vector2, align: PlaneInnerAlign) {
        var inertiaOffset = Vector2.zero
        if speed.length > 400 {
            inertiaOffset = speed / 4
        }
        if inertiaOffset.length > moving.offset.length * 2 {
            inertiaOffset = inertiaOffset.with(length: moving.offset.length)
        }
        subtracer.instant("inertiaOffset \(inertiaOffset) \(rect(of: moving) + inertiaOffset) \(rootFrame)")

        let clampingOffset = (rect(of: moving) + inertiaOffset).clampingOffset(by: rootFrame)
        subtracer.instant("clampingOffset \(clampingOffset)")

        let clamped = rect(of: moving) + inertiaOffset + clampingOffset
        let align = rootFrame.nearestInnerAlign(of: clamped.center, isCorner: true)
        subtracer.instant("align \(align)")

        guard var aligned = get(id: moving.id) else { return (.zero, .topLeading) }
        aligned.align = align

        let alignOffset = rect(of: aligned).origin.offset(to: rect(of: moving).origin)
        subtracer.instant("alignOffset \(alignOffset), \(rect(of: aligned)), \(rect(of: moving))")

        return (alignOffset, align)
    }

    func floatingPanelDrag(panelId: UUID) -> MultipleGesture? {
        if popoverPanelIds.contains(panelId) {
            return nil
        }
        return .init(
            configs: .init(coordinateSpace: .global),
            onPressEnd: { cancelled in
                if cancelled {
                    self.update(movingPanelMap: self.movingPanelMap.cloned { $0[panelId] = nil })
                }
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
    func onResize(panelId: UUID, maxHeight: Scalar) {
        guard let panel = get(id: panelId) else { return }
        let maxHeight = max(floatingPanelMinHeight, maxHeight)
        withStoreUpdating {
            focus(panelId: panelId)
            update(panelMap: panelMap.cloned { $0[panel.id] = panel.cloned { $0.maxHeight = maxHeight } })
        }
    }

    func setFrame(panelId: UUID, _ frame: CGRect) {
        let _r = subtracer.range("set panel \(panelId) frame \(frame)"); defer { _r() }
        guard let panel = get(id: panelId) else { return }
        update(panelFrameMap: panelFrameMap.cloned { $0[panel.id] = frame })
    }

    func setRootFrame(_ frame: CGRect) {
        let _r = subtracer.range("set root frame \(frame)"); defer { _r() }
        update(rootFrame: frame)
    }

    func floatingPanelResize(panelId: UUID) -> MultipleGesture? {
        if popoverPanelIds.contains(panelId) {
            return nil
        }
        return .init(
            configs: .init(coordinateSpace: .global),
            onPressEnd: { cancelled in
                if cancelled {
                    self.update(movingPanelMap: self.movingPanelMap.cloned { $0[panelId] = nil })
                }
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
