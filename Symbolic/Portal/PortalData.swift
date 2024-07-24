import SwiftUI

// MARK: - PanelData

struct PortalData: Identifiable {
    let id: UUID = .init()
    let view: AnyView

    var isModal: Bool
    var reference: CGRect
    var align: PlaneOuterAlign = .topLeading
}

extension PortalData: EquatableBy {
    var equatableBy: some Equatable {
        id; reference; align
    }
}

extension PortalData: TriviallyCloneable {}

// MARK: - enviroments

private struct PortalIdKey: EnvironmentKey {
    static let defaultValue: UUID = .init()
}

extension EnvironmentValues {
    var portalId: UUID {
        get { self[PortalIdKey.self] }
        set { self[PortalIdKey.self] = newValue }
    }
}
