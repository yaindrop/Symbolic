import SwiftUI

enum PanelAppearance: Equatable {
    case floatingPrimary
    case floatingSecondary
    case floatingHidden
    case popoverSection
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

// MARK: - PanelStyle

struct PanelStyle: Equatable {
    var appearance: PanelAppearance
    var squeezed: Bool

    var padding: CGSize
    var align: PlaneInnerAlign
    var maxHeight: Scalar
}

// MARK: - MovingPanelData

struct MovingPanelData: Equatable {
    let id: UUID
    var globalDragPosition: Point2
    var offset: Vector2
    var align: PlaneInnerAlign
    var ended: Bool = false
}

extension MovingPanelData: TriviallyCloneable {}

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

private struct PanelAppearanceKey: EnvironmentKey {
    static let defaultValue: PanelAppearance = .floatingPrimary
}

extension EnvironmentValues {
    var panelAppearance: PanelAppearance {
        get { self[PanelAppearanceKey.self] }
        set { self[PanelAppearanceKey.self] = newValue }
    }
}
