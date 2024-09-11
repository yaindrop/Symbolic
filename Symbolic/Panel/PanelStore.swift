import SwiftUI

private let subtracer = tracer.tagged("PanelStore")

typealias PanelMap = OrderedMap<UUID, PanelData>
typealias PanelFrameMap = [UUID: CGRect]
typealias AlignPanelMap = [PlaneInnerAlign: [UUID]]
typealias PanelFloatingStyleMap = [UUID: PanelFloatingStyle]

// MARK: - PanelStore

class PanelStore: Store {
    @Trackable var panelMap = PanelMap()

    // floating
    @Trackable var moving: PanelMovingData?
    @Trackable var resizing: UUID?
    @Trackable var switching: PanelSwitchingData?

    @Trackable var rootFrame: CGRect = .zero
    @Trackable var panelFrameMap = PanelFrameMap()

    // popover
    @Trackable var popoverPanelIds: Set<UUID> = []
    @Trackable var popoverActive: Bool = false
    @Trackable var popoverButtonFrame: CGRect = .zero

    @Derived({ $0.deriveAlignPanelMap }) var alignPanelMap
    @Derived({ $0.derivePanelFloatingStyleMap }) var panelFloatingStyleMap
}

private extension PanelStore {
    func update(panelMap: PanelMap) {
        update { $0(\._panelMap, panelMap) }
    }

    func update(moving: PanelMovingData?) {
        update { $0(\._moving, moving) }
    }

    func update(resizing: UUID?) {
        update { $0(\._resizing, resizing) }
    }

    func update(switching: PanelSwitchingData?) {
        update { $0(\._switching, switching) }
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

    var floatingSafeArea: Scalar { 36 }

    var floatingMinimizedGap: Scalar { 64 }
}

extension PanelStore {
    func get(id: UUID) -> PanelData? { panelMap.get(id) }

    var panelIds: [UUID] { panelMap.keys }

    var panels: [PanelData] { panelMap.values }

    var floatingPanelIds: [UUID] {
        panelIds.filter { !popoverPanelIds.contains($0) }
    }

    var displayingFloatingPanelIds: [UUID] {
        guard let switching else { return floatingPanelIds }
        let peers = peers(of: switching.id),
            peerSet = Set(peers)
        return floatingPanelIds.filter { !peerSet.contains($0) } + peers
    }

    var floatingPanels: [PanelData] {
        floatingPanelIds.compactMap { get(id: $0) }
    }

    func maxHeight(of id: UUID) -> Scalar {
        guard let panel = get(id: id) else { return floatingMaxHeight }
        return min(panel.maxHeight, floatingMaxHeight)
    }

    // moving

    func moving(of id: UUID) -> PanelMovingData? {
        guard let moving, moving.id == id else { return nil }
        return moving
    }

    func align(of id: UUID) -> PlaneInnerAlign {
        guard let panel = get(id: id) else { return .topLeading }
        guard let moving = moving(of: id) else { return panel.align }
        return moving.align
    }

    func movable(of id: UUID) -> Bool {
        guard let moving else { return true }
        return moving.id == id
    }

    func resizable(of id: UUID) -> Bool {
        guard let resizing else { return true }
        return resizing == id
    }

    func switchable(of id: UUID) -> Bool {
        guard primaryId(of: id) == id else { return false }
        let peers = peers(of: id)
        return peers.count > 1
    }

    func floatingStyle(of id: UUID) -> PanelFloatingStyle? {
        panelFloatingStyleMap.get(id)
    }

    // frame

    var freeSpace: CGRect {
        let floatingPanels = floatingPanels,
            hasLeading = floatingPanels.contains { $0.align.isLeading },
            hasTrailing = floatingPanels.contains { $0.align.isTrailing },
            width = floatingPadding.width + floatingWidth
        let minX = rootFrame.minX + (hasLeading ? width : 0),
            maxX = rootFrame.maxX - (hasTrailing ? width : 0)
        guard maxX - minX > floatingWidth else { return rootFrame }
        return .init(x: minX, y: rootFrame.minY, width: maxX - minX, height: rootFrame.height)
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

private extension PanelStore {
    var deriveAlignPanelMap: AlignPanelMap {
        floatingPanels.reduce(into: AlignPanelMap()) { dict, panel in
            let align = align(of: panel.id)
            dict[align] = (dict[align] ?? []) + [panel.id]
        }
    }

    func frame(of id: UUID) -> CGRect? {
        panelFrameMap.get(id)
    }

    func panelIds(at align: PlaneInnerAlign) -> [UUID] {
        alignPanelMap.get(align) ?? []
    }

    func primaryId(at align: PlaneInnerAlign) -> UUID? {
        panelIds(at: align).last
    }

    func peers(of id: UUID) -> [UUID] {
        alignPanelMap.get(align(of: id)) ?? []
    }

    func primaryId(of id: UUID) -> UUID? {
        peers(of: id).last
    }

    func minimized(of id: UUID) -> Bool {
        let align = align(of: id)
        guard primaryId(at: align) == id else { return false }
        let oppositeAlign = PlaneInnerAlign(horizontal: align.horizontal, vertical: align.vertical.flipped)
        guard let index = floatingPanelIds.firstIndex(of: id),
              let oppositeId = primaryId(at: oppositeAlign),
              let oppositeIndex = floatingPanelIds.firstIndex(of: oppositeId),
              index < oppositeIndex else { return false }
        guard let frame = frame(of: id),
              let oppositeFrame = self.frame(of: oppositeId) else { return false }
        return frame.height + oppositeFrame.height + floatingSafeArea * 2 > rootFrame.height
    }

    var switchingOffset: Scalar {
        abs(switching?.offset.dx ?? 0)
    }

    var switchingOrder: Int {
        1 + Int(floor(switchingOffset / floatingMinimizedGap))
    }

    func switchingOrder(of id: UUID) -> Int {
        peers(of: id).reversed().firstIndex(of: id) ?? 0
    }

    func switchingGap(of id: UUID) -> CGSize {
        let order = switchingOrder(of: id)
        guard let primaryId = primaryId(of: id),
              let primaryFrame = frame(of: primaryId) else { return .zero }
        return .init(floatingMinimizedGap * Scalar(order - 1), primaryFrame.height + floatingPadding.height)
    }

    var switchingSelectedId: UUID? {
        guard let switching else { return nil }
        let peers = Array(peers(of: switching.id).reversed())
        guard !peers.isEmpty else { return nil }
        let order = min(switchingOrder, peers.count - 1)
        return peers[order]
    }

    func switchingStyleGap(of id: UUID) -> CGSize {
        var gap = switchingGap(of: id)
        if switchingOffset < gap.width {
            gap.width += floatingMinimizedGap
        }
        return gap
    }

    private var derivePanelFloatingStyleMap: PanelFloatingStyleMap {
        floatingPanelIds.reduce(into: PanelFloatingStyleMap()) { dict, id in
            dict[id] = {
                let primaryId = primaryId(of: id),
                    align = align(of: id)
                if primaryId == id {
                    return .primary(minimized: minimized(of: id))
                } else if let switching, switching.id == primaryId {
                    let selected = switchingSelectedId == id,
                        gap = switchingStyleGap(of: id) + (selected ? Vector2(0, floatingMinimizedGap / 2) : .zero),
                        offset = Point2.zero.alignedPoint(at: align, gap: gap)
                    return .switching(offset: .init(offset), selected: selected)
                } else {
                    let primaryMoving = primaryId == moving?.id,
                        isSecondary = peers(of: id).dropLast().last == id,
                        opacity = primaryMoving && isSecondary ? 0.5 : 0
                    return .secondary(opacity: opacity)
                }
            }()
        }
    }
}

// MARK: actions

extension PanelStore {
    func register(name: String, align: PlaneInnerAlign = .topLeading, @ViewBuilder _ panel: @escaping () -> any View) {
        let panel = PanelData(name: name, view: AnyView(panel()), align: align)
        update(panelMap: panelMap.cloned { $0[panel.id] = panel })
    }

    func deregister(id: UUID) {
        update(panelMap: panelMap.cloned { $0.removeValue(forKey: id) })
    }

    func clear() {
        update(panelMap: [:])
    }
}

private extension PanelStore {
    func focus(on id: UUID) {
        update(panelMap: panelMap.cloned { $0[id] = $0.removeValue(forKey: id) })
    }

    func spin(on id: UUID) {
        let peers = peers(of: id)
        guard let panel = get(id: id),
              let primaryId = peers.last,
              let primary = get(id: primaryId) else { return }
        update(panelMap: panelMap.cloned {
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
            update(panelMap: panelMap.cloned { $0[id]?.align = .topTrailing })
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
        guard let style = floatingStyle(of: id),
              !style.isPrimary else { return }
        let peers = peers(of: id)
        if id == peers.last {
            focus(on: id)
        } else {
            spin(on: id)
        }
    }

    func onMoving(of id: UUID, _ v: DragGesture.Value) {
        let _r = subtracer.range(type: .intent, "moving \(id) by \(v.offset)"); defer { _r() }
        var moving: PanelMovingData
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
        withStoreUpdating(.syncNotify) {
            update(panelMap: panelMap.cloned { $0[id] = panel.cloned { $0.align = moveTarget.align } })
            update(moving: moving)
        }
    }

    func resetMoving(of id: UUID) {
        guard let moving,
              moving.id == id,
              moving.ended else { return }
        let _r = subtracer.range(type: .intent, "reset moving of by \(id)"); defer { _r() }
        withStoreUpdating(.animation(.custom(.spring(duration: 0.5)))) {
            update(moving: nil)
        }
    }

    private func rect(of panel: PanelData) -> CGRect {
        let size = frame(of: panel.id)?.size ?? .zero
        return rootFrame.alignedBox(at: panel.align, size: size, gap: floatingPadding)
    }

    private func rect(of moving: PanelMovingData) -> CGRect {
        guard let panel = get(id: moving.id) else { return .zero }
        return rect(of: panel) + moving.offset
    }

    private func moveTarget(moving: PanelMovingData, speed: Vector2) -> (offset: Vector2, align: PlaneInnerAlign) {
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

    private func onDragResize(of id: UUID, _ v: DragGesture.Value) {
        let align = align(of: id),
            frame = frame(of: id) ?? .zero,
            oppositeY = align.isTop ? frame.minY : frame.maxY,
            maxHeight = abs(v.location.y - oppositeY)
        onResize(of: id, maxHeight: maxHeight)
    }

    private func onResize(of id: UUID, maxHeight: Scalar) {
        guard let panel = get(id: id) else { return }
        let maxHeight = max(floatingMinHeight, maxHeight)
        withStoreUpdating {
            focus(on: id)
            update(panelMap: panelMap.cloned { $0[panel.id] = panel.cloned { $0.maxHeight = maxHeight } })
        }
    }

    // callback from resized view
    func setFrame(of id: UUID, _ frame: CGRect) {
        let _r = subtracer.range("set panel \(id) frame \(frame)"); defer { _r() }
        update(panelFrameMap: panelFrameMap.cloned { $0[id] = frame })
    }

    func setRootFrame(_ frame: CGRect) {
        let _r = subtracer.range("set root frame \(frame)"); defer { _r() }
        update(rootFrame: frame)
    }
}

// MARK: switching

extension PanelStore {
    func switchingGesture(of id: UUID) -> MultipleGesture {
        .init(
            configs: .init(coordinateSpace: .global),
            onPress: { self.onDragSwitch(of: id, $0) },
            onPressEnd: { _, _ in self.update(switching: nil) },
            onTap: { _ in self.spin(on: id) },
            onDrag: { self.onDragSwitch(of: id, $0) },
            onDragEnd: { self.onDragSwitchEnd(of: id, $0) }
        )
    }

    private func onDragSwitch(of id: UUID, _ v: DragGesture.Value) {
        update(switching: .init(id: id, offset: v.offset))
    }

    private func onDragSwitchEnd(of _: UUID, _: DragGesture.Value) {
        withStoreUpdating {
            if let id = switchingSelectedId, let panel = get(id: id) {
                update(panelMap: panelMap.cloned {
                    $0.removeValue(forKey: id)
                    $0[id] = panel
                })
            }
            update(switching: nil)
        }
    }
}
