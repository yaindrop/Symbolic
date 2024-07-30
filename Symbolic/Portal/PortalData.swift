import SwiftUI

struct PortalConfigs {
    var attached: Bool = false
    var isModal: Bool = false
    var align: PlaneOuterAlign = .topLeading
    var gap: CGSize = .zero
}

extension PortalConfigs: EquatableBy {
    var attachedState: AnyState? { attached ? .init() : nil }

    var equatableBy: some Equatable {
        attachedState; isModal; align; gap
    }
}

// MARK: - PanelData

struct PortalData: Identifiable {
    let configs: PortalConfigs
    let id: UUID = .init()

    var view: AnyView
    var reference: CGRect
}

extension PortalData: UniqueEquatable {}

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
