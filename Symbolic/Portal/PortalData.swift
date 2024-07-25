import SwiftUI

struct PortalConfigs: Equatable {
    var isModal: Bool = false
    var align: PlaneOuterAlign = .topLeading
    var gap: CGSize = .zero
}

// MARK: - PanelData

struct PortalData: Identifiable {
    let configs: PortalConfigs
    let id: UUID = .init()
    let view: AnyView

    var reference: CGRect
}

extension PortalData: EquatableBy {
    var equatableBy: some Equatable {
        configs; id; reference
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
