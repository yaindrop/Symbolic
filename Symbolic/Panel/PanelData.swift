import SwiftUI

enum PanelFloatingState: Equatable {
    case primary
    case secondary
    case hidden
}

// MARK: - PanelData

struct PanelData: Identifiable {
    let id: UUID = .init()
    let view: (_ panelId: UUID) -> AnyView

    var size: CGSize = .zero
    var align: PlaneInnerAlign = .topLeading
}

extension PanelData: EquatableBy {
    var equatableBy: some Equatable {
        id; size; align
    }
}

extension PanelData: TriviallyCloneable {}

struct MovingPanelData: Equatable {
    let data: PanelData
    var globalPosition: Point2
    var offset: Vector2
    var align: PlaneInnerAlign?
    var endTask: Task<Void, any Error>?
}

extension MovingPanelData: TriviallyCloneable {}
