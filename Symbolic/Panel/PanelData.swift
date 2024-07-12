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

    var maxHeight: Scalar = 400
    var align: PlaneInnerAlign = .topLeading
}

extension PanelData: EquatableBy {
    var equatableBy: some Equatable {
        id; maxHeight; align
    }
}

extension PanelData: TriviallyCloneable {}

// MARK: - MovingPanelData

struct MovingPanelData: Equatable {
    let id: UUID
    var globalDragPosition: Point2
    var offset: Vector2
    var align: PlaneInnerAlign
}

extension MovingPanelData: TriviallyCloneable {}

// MARK: - enviroments

private struct PanelIdKey: EnvironmentKey {
    static let defaultValue: UUID = .init()
}

extension EnvironmentValues {
    var panelId: UUID {
        get { self[PanelIdKey.self] }
        set { self[PanelIdKey.self] = newValue }
    }
}

private struct PanelScrollProxy: EnvironmentKey {
    static let defaultValue: ScrollViewProxy? = nil
}

extension EnvironmentValues {
    var panelScrollProxy: ScrollViewProxy? {
        get { self[PanelScrollProxy.self] }
        set { self[PanelScrollProxy.self] = newValue }
    }
}
