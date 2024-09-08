import SwiftUI

enum PanelFloatingStyle: Equatable {
    case primary(align: PlaneInnerAlign)
    case minimized(align: PlaneInnerAlign, offset: Vector2)
}

extension PanelFloatingStyle {
    var isPrimary: Bool { if case .primary = self { true } else { false } }

    var align: PlaneInnerAlign {
        switch self {
        case let .primary(align): align
        case let .minimized(align, _): align
        }
    }

    var rotation3D: (angle: Angle, axis: (x: Scalar, y: Scalar, z: Scalar), anchor: UnitPoint) {
        guard !isPrimary else { return (.zero, (0, 1, 0), .zero) }
        let angle: Scalar = 15
        return (
            angle: .degrees((align.isLeading ? 1 : -1) * angle),
            axis: (0, 1, 0),
            anchor: align.isLeading ? .leading : .trailing
        )
    }

    var scale: (Scalar, anchor: UnitPoint) {
        switch self {
        case .primary: (1, align.unitPoint)
        case .minimized: (0.4, align.unitPoint)
        }
    }

    var offset: Vector2 {
        switch self {
        case .primary: .zero
        case let .minimized(_, offset): offset
        }
    }
}

// MARK: - PanelData

struct PanelData: Identifiable {
    let id: UUID = .init()
    let name: String
    let view: AnyView

    var align: PlaneInnerAlign = .topLeading
    var maxHeight: Scalar = 400
}

extension PanelData: EquatableBy {
    var equatableBy: some Equatable {
        id; maxHeight; align
    }
}

extension PanelData: TriviallyCloneable {}

// MARK: - PanelMovingData

struct PanelMovingData: Equatable {
    let id: UUID
    var globalDragPosition: Point2
    var offset: Vector2
    var align: PlaneInnerAlign
    var ended: Bool = false
}

extension PanelMovingData: TriviallyCloneable {}

// MARK: - environments

private struct PanelIdKey: EnvironmentKey {
    static let defaultValue: UUID = .init()
}

extension EnvironmentValues {
    var panelId: UUID {
        get { self[PanelIdKey.self] }
        set { self[PanelIdKey.self] = newValue }
    }
}

private struct PanelScrollProxyKey: EnvironmentKey {
    static let defaultValue: ScrollViewProxy? = nil
}

extension EnvironmentValues {
    var panelScrollProxy: ScrollViewProxy? {
        get { self[PanelScrollProxyKey.self] }
        set { self[PanelScrollProxyKey.self] = newValue }
    }
}

private struct PanelScrollFrameKey: EnvironmentKey {
    static let defaultValue: CGRect = .zero
}

extension EnvironmentValues {
    var panelScrollFrame: CGRect {
        get { self[PanelScrollFrameKey.self] }
        set { self[PanelScrollFrameKey.self] = newValue }
    }
}

private struct PanelFloatingStyleKey: EnvironmentKey {
    static let defaultValue: PanelFloatingStyle = .primary(align: .topLeading)
}

extension EnvironmentValues {
    var panelFloatingStyle: PanelFloatingStyle {
        get { self[PanelFloatingStyleKey.self] }
        set { self[PanelFloatingStyleKey.self] = newValue }
    }
}
