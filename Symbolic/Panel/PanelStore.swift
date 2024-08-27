import SwiftUI

private let subtracer = tracer.tagged("PanelStore")

typealias PanelMap = OrderedMap<UUID, PanelData>

// MARK: - PanelStore

class PanelStore: Store {
    @Trackable var map = PanelMap()

    // floating
    @Trackable var moving: MovingPanelData?
    @Trackable var resizing: UUID?
    @Trackable var rootFrame: CGRect = .zero
    @Trackable var panelFrameMap: [UUID: CGRect] = [:]

    // popover
    @Trackable var popoverActive: Bool = false
    @Trackable var popoverButtonFrame: CGRect = .zero
    @Trackable var popoverPanelIds: Set<UUID> = []

    @Derived({ $0.deriveStyleMap }) var styleMap
}

private extension PanelStore {
    func update(map: PanelMap) {
        update { $0(\._map, map) }
    }

    func update(moving: MovingPanelData?) {
        update { $0(\._moving, moving) }
    }

    func update(resizing: UUID?) {
        update { $0(\._resizing, resizing) }
    }

    func update(rootFrame: CGRect) {
        update { $0(\._rootFrame, rootFrame) }
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
    var floatingWidth: Scalar { 320 }

    var floatingMinHeight: Scalar { 240 }

    var floatingMaxHeight: Scalar { rootFrame.height - floatingSafeArea * 2 }

    var floatingPadding: CGSize { .init(squared: 12) }

    var floatingPaddingLarge: CGSize { .init(squared: 24) }

    var floatingSafeArea: Scalar { 36 }
}

extension PanelStore {
    func get(id: UUID) -> PanelData? { map.get(id) }
    func style(id: UUID) -> PanelStyle? { styleMap.get(id) }

    var panelIds: [UUID] { map.keys }
    var panels: [PanelData] { map.values }
}

extension PanelStore {
    var floatingPanelIds: [UUID] { panelIds.filter { !popoverPanelIds.contains($0) } }

    var floatingPanels: [PanelData] { floatingPanelIds.compactMap { get(id: $0) } }

    func movingOffset(of id: UUID) -> Vector2 {
        guard let moving, moving.id == id else { return .zero }
        return moving.offset
    }

    func movingEnded(of id: UUID) -> Bool {
        guard let moving, moving.id == id else { return false }
        return moving.ended
    }

    func movable(of id: UUID) -> Bool {
        guard let moving else { return true }
        return moving.id == id
    }

    func resizable(of id: UUID) -> Bool {
        guard let resizing else { return true }
        return resizing == id
    }

    var freeSpace: CGRect {
        let floatingPanels = floatingPanels
        var minX = rootFrame.minX + floatingPaddingLarge.width, maxX = rootFrame.maxX - floatingPaddingLarge.width
        if floatingPanels.contains(where: { $0.align.isLeading }) {
            minX += floatingWidth
        }
        if floatingPanels.contains(where: { $0.align.isTrailing }) {
            maxX -= floatingWidth
        }
        if maxX - minX > floatingWidth {
            return .init(x: minX, y: rootFrame.minY, width: maxX - minX, height: rootFrame.height)
        }
        return rootFrame
    }
}

extension PanelStore {
    var popoverPanels: [PanelData] { panels.filter { popoverPanelIds.contains($0.id) } }

    var popoverButtonHovering: Bool {
        guard let moving else { return false }
        return popoverButtonFrame.contains(moving.globalDragPosition)
    }
}

// MARK: derived

extension PanelStore {
    private var deriveStyleMap: [UUID: PanelStyle] {
        let alignMap = panels.reduce(into: [UUID: PlaneInnerAlign]()) { dict, panel in
            dict[panel.id] = {
                if let moving, moving.id == panel.id {
                    moving.align
                } else {
                    panel.align
                }
            }()
        }

        let squeezedMap = panelIds.reduce(into: [UUID: Bool]()) { dict, id in
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

                guard let frontFrame = panelFrameMap.get(front.id), let neighborFrame = panelFrameMap.get(neighbor.id) else { return false }
                return frontFrame.height + neighborFrame.height + floatingSafeArea * 2 > rootFrame.height
            }()
        }

        let appearanceMap = panelIds.reduce(into: [UUID: PanelAppearance]()) { dict, id in
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

        let paddingMap = panelIds.reduce(into: [UUID: CGSize]()) { dict, id in
            dict[id] = {
                guard moving?.id != id else { return floatingPadding }
                let squeezed = squeezedMap[id] ?? false
                guard !squeezed else { return floatingPaddingLarge }
                let align = alignMap[id]
                let peers = floatingPanels.filter { alignMap[$0.id] == align }
                return peers.count > 1 ? floatingPaddingLarge : floatingPadding
            }()
        }

        let maxHeightMap = panels.reduce(into: [UUID: Scalar]()) { dict, panel in
            dict[panel.id] = min(panel.maxHeight, floatingMaxHeight)
        }

        return panelIds.reduce(into: [UUID: PanelStyle]()) { dict, id in
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

// MARK: actions

extension PanelStore {
    func register(name: String, align: PlaneInnerAlign = .topLeading, @ViewBuilder _ panel: @escaping () -> any View) {
        let panel = PanelData(name: name, view: AnyView(panel()), align: align)
        update(map: map.cloned { $0[panel.id] = panel })
    }

    func deregister(id: UUID) {
        update(map: map.cloned { $0.removeValue(forKey: id) })
    }

    func clear() {
        update(map: [:])
    }
}

private extension PanelStore {
    func focus(on id: UUID) {
        update(map: map.cloned { $0[id] = $0.removeValue(forKey: id) })
    }

    func spin(on id: UUID) {
        guard let style = styleMap.get(id) else { return }
        let peers = panelIds.filter { styleMap.get($0)?.align == style.align }
        guard let primaryId = peers.last,
              let primary = get(id: primaryId),
              let panel = get(id: id) else { return }
        update(map: map.cloned {
            $0.removeValue(forKey: primaryId)
            $0.removeValue(forKey: id)
            $0.insert((primaryId, primary), at: 0)
            $0.append((id, panel))
        })
    }
}

extension PanelStore {
    func togglePopover() {
        update(popoverActive: !popoverActive)
    }

    func setPopoverButtonFrame(_ frame: CGRect) {
        update(popoverButtonFrame: frame)
    }

    func setFloating(id: UUID) {
        withStoreUpdating {
            update(popoverPanelIds: popoverPanelIds.cloned { $0.remove(id) })
            update(map: map.cloned { $0[id]?.align = .topTrailing })
            update(popoverActive: false)
        }
    }
}

// MARK: moving

extension PanelStore {
    func movingGesture(of id: UUID) -> MultipleGesture {
        .init(
            configs: .init(coordinateSpace: .global),
            onPress: { _ in self.onPress(of: id) },
            onPressEnd: { _, cancelled in
                guard cancelled else { return }
                self.resetMoving(of: id)
            },
            onDrag: { self.onMoving(of: id, $0) },
            onDragEnd: { self.onMoved(of: id, $0) }
        )
    }

    func onPress(of id: UUID) {
        guard let style = styleMap.get(id),
              style.appearance == .floatingSecondary else { return }
        if style.squeezed {
            focus(on: id)
        } else {
            spin(on: id)
        }
    }

    func onMoving(of id: UUID, _ v: DragGesture.Value) {
        let _r = subtracer.range(type: .intent, "moving \(id) by \(v.offset)"); defer { _r() }
        var moving: MovingPanelData
        if let prev = self.moving, prev.id == id {
            moving = prev
            moving.globalDragPosition = v.location
            moving.offset = v.offset
        } else {
            guard let panel = get(id: id) else { return }
            moving = .init(id: id, globalDragPosition: v.location, offset: v.offset, align: panel.align)
        }

        let moveTarget = moveTarget(moving: moving, speed: .zero)
        moving.align = moveTarget.align
        moving.offset = moveTarget.offset
        withStoreUpdating {
            update(popoverActive: false)
            focus(on: id)
            update(moving: moving)
        }
    }

    func onMoved(of id: UUID, _ v: DragGesture.Value) {
        guard let panel = get(id: id),
              var moving = moving, moving.id == id else { return }
        moving.globalDragPosition = v.location
        moving.offset = v.offset

        let _r = subtracer.range(type: .intent, "moved \(id) by \(v.offset) with speed \(v.speed)"); defer { _r() }
        if popoverButtonFrame.contains(moving.globalDragPosition) {
            withStoreUpdating {
                update(popoverPanelIds: popoverPanelIds.cloned { $0.insert(id) })
                update(moving: nil)
            }
            return
        }

        let moveTarget = moveTarget(moving: moving, speed: v.speed)
        moving.align = moveTarget.align
        moving.offset = moveTarget.offset
        moving.ended = true
        withStoreUpdating(configs: .init(syncNotify: true)) {
            update(map: map.cloned { $0[id] = panel.cloned { $0.align = moveTarget.align } })
            update(moving: moving)
        }
    }

    func resetMoving(of id: UUID) {
        guard moving?.id == id else { return }
        withStoreUpdating(configs: .init(animation: .custom(.spring(duration: 0.5)))) {
            update(moving: nil)
        }
    }

    private func rect(of panel: PanelData) -> CGRect {
        let size = panelFrameMap.get(panel.id)?.size ?? .zero
        return rootFrame.alignedBox(at: panel.align, size: size, gap: floatingPadding)
    }

    private func rect(of moving: MovingPanelData) -> CGRect {
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
}

// MARK: resizing

extension PanelStore {
    func resizingGesture(of id: UUID) -> MultipleGesture {
        .init(
            configs: .init(coordinateSpace: .global),
            onPress: { _ in self.update(resizing: id) },
            onPressEnd: { _, _ in self.update(resizing: nil) },
            onDrag: { self.onDragResize(of: id, $0) },
            onDragEnd: { self.onDragResize(of: id, $0) }
        )
    }

    func onDragResize(of id: UUID, _ v: DragGesture.Value) {
        guard let align = style(id: id)?.align else { return }
        let frame = panelFrameMap.get(id) ?? .zero
        let oppositeY = align.isTop ? frame.minY : frame.maxY
        onResize(of: id, maxHeight: abs(v.location.y - oppositeY))
    }

    func onResize(of id: UUID, maxHeight: Scalar) {
        guard let panel = get(id: id) else { return }
        let maxHeight = max(floatingMinHeight, maxHeight)
        withStoreUpdating {
            focus(on: id)
            update(map: map.cloned { $0[panel.id] = panel.cloned { $0.maxHeight = maxHeight } })
        }
    }

    func setFrame(of id: UUID, _ frame: CGRect) {
        let _r = subtracer.range("set panel \(id) frame \(frame)"); defer { _r() }
        update(panelFrameMap: panelFrameMap.cloned { $0[id] = frame })
    }

    func setRootFrame(_ frame: CGRect) {
        let _r = subtracer.range("set root frame \(frame)"); defer { _r() }
        update(rootFrame: frame)
    }
}
