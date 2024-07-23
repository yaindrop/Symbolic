import SwiftUI

// MARK: - PanelData

struct PortalData: Identifiable {
    let id: UUID = .init()
    let view: AnyView

    var reference: CGRect
    var align: PlaneOuterAlign = .topLeading
}

extension PortalData: EquatableBy {
    var equatableBy: some Equatable {
        id; reference; align
    }
}

extension PortalData: TriviallyCloneable {}
