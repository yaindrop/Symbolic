import SwiftUI

private let subtracer = tracer.tagged("PortalStore")

typealias PortalMap = OrderedMap<UUID, PortalData>

// MARK: - PortalStore

class PortalStore: Store {
    @Trackable var portalMap = PortalMap()
}

private extension PortalStore {
    func update(portalMap: PortalMap) {
        update { $0(\._portalMap, portalMap) }
    }
}

extension PortalStore {
    func register(reference: CGRect, align: PlaneOuterAlign = .topLeading, @ViewBuilder _ view: @escaping () -> any View) -> UUID {
        let portal = PortalData(view: AnyView(view()), reference: reference, align: align)
        update(portalMap: portalMap.cloned { $0[portal.id] = portal })
        return portal.id
    }

    func setFrame(of id: UUID, _ frame: CGRect) {
        update(portalMap: portalMap.cloned { $0[id]?.reference = frame })
    }

    func deregister(id: UUID) {
        update(portalMap: portalMap.cloned { $0.removeValue(forKey: id) })
    }
}

struct PortalReference<Content: View>: View {
    var align: PlaneOuterAlign = .topLeading
    @ViewBuilder var content: () -> Content

    @State private var frame: CGRect = .zero
    @State private var portalId: UUID?

    var body: some View {
        Color.invisibleSolid
            .allowsHitTesting(false)
            .geometryReader { frame = $0.frame(in: .global) }
            .onAppear { portalId = global.portal.register(reference: frame, align: align, content) }
            .onChange(of: frame) { portalId.map { global.portal.setFrame(of: $0, frame) } }
            .onDisappear { portalId.map { global.portal.deregister(id: $0) } }
    }
}
