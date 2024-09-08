import SwiftUI

// MARK: - PanelFloatingStyle

enum PanelFloatingStyle: Equatable {
    case primary(minimized: Bool)
    case secondary(opacity: Scalar)
    case switching(offset: Vector2, highlighted: Bool)
}

extension PanelFloatingStyle {
    var isPrimary: Bool { if case let .primary(minimized) = self { !minimized } else { false } }
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
    static let defaultValue: PanelFloatingStyle = .primary(minimized: false)
}

extension EnvironmentValues {
    var panelFloatingStyle: PanelFloatingStyle {
        get { self[PanelFloatingStyleKey.self] }
        set { self[PanelFloatingStyleKey.self] = newValue }
    }
}
