import SwiftUI

// MARK: - PanelFloatingStyle

enum PanelFloatingStyle: Equatable {
    case primary(align: PlaneInnerAlign)
    case minimized(align: PlaneInnerAlign)
    case secondary(align: PlaneInnerAlign, opacity: Scalar)
    case switching(align: PlaneInnerAlign, offset: Vector2)
}

extension PanelFloatingStyle {
    var isPrimary: Bool { if case .primary = self { true } else { false } }
    var isMinimized: Bool { if case .minimized = self { true } else { false } }
    var isSecondary: Bool { if case .secondary = self { true } else { false } }
    var isSwitching: Bool { if case .switching = self { true } else { false } }

    var align: PlaneInnerAlign {
        switch self {
        case let .primary(align),
             let .minimized(align),
             let .secondary(align, _),
             let .switching(align, _): align
        }
    }

    var rotation3DAngle: Angle {
        switch self {
        case .secondary, .switching: .degrees((align.isLeading ? 1 : -1) * 15)
        default: .zero
        }
    }

    var rotation3DAxis: (x: Scalar, y: Scalar, z: Scalar) {
        (0, 1, 0)
    }

    var rotation3DAnchor: UnitPoint {
        switch self {
        case .secondary: align.unitPoint
        case .switching: align.isLeading ? .leading : .trailing
        default: .leading
        }
    }

    var scale: Scalar {
        switch self {
        case .primary: 1
        case .minimized, .secondary, .switching: 0.4
        }
    }

    var scaleAnchor: UnitPoint {
        align.unitPoint
    }

    var offset: Vector2 {
        switch self {
        case .primary, .minimized, .secondary: .zero
        case let .switching(_, offset): offset
        }
    }

    var opacity: Scalar {
        switch self {
        case let .secondary(_, opacity): opacity
        default: 1
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

// MARK: - PanelSwitchingData

struct PanelSwitchingData: Equatable {
    let id: UUID
    var offset: Vector2
}

extension PanelSwitchingData: TriviallyCloneable {}

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
