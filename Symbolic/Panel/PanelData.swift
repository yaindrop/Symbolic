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
    let view: AnyView

    var size: CGSize = .zero
    var align: PlaneInnerAlign = .topLeading
}

extension PanelData: EquatableBy {
    var equatableBy: some Equatable {
        id; size; align
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

// MARK: - PanelIdKey

private struct PanelIdKey: EnvironmentKey {
    static let defaultValue: UUID = .init()
}

extension EnvironmentValues {
    var panelId: UUID {
        get { self[PanelIdKey.self] }
        set { self[PanelIdKey.self] = newValue }
    }
}
