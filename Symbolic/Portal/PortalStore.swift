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
    func register(configs: PortalConfigs = .init(), reference: CGRect, @ViewBuilder _ view: @escaping () -> any View) -> UUID {
        let portal = PortalData(configs: configs, view: AnyView(view()), reference: reference)
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

struct PortalReference<Content: View>: View, SelectorHolder {
    @Binding var isPresented: Bool
    var configs: PortalConfigs = .init()
    @ViewBuilder var content: () -> Content

    class Selector: SelectorBase {
        @Selected({ global.portal.portalMap }) var portalMap
    }

    @SelectorWrapper var selector

    @State private var frame: CGRect = .zero
    @State private var portalId: UUID?

    private var deregistered: Bool {
        guard let portalId else { return false }
        return selector.portalMap.value(key: portalId) == nil
    }

    var body: some View {
        setupSelector {
            if isPresented {
                Color.clear
                    .geometryReader { frame = $0.frame(in: .global) }
                    .onChange(of: deregistered) { _, deregistered in if deregistered { isPresented = false } }
                    .onChange(of: frame) { portalId.map { global.portal.setFrame(of: $0, frame) } }
                    .onAppear { portalId = global.portal.register(configs: configs, reference: frame, content) }
                    .onDisappear { portalId.map { global.portal.deregister(id: $0) } }
            }
        }
    }
}

extension View {
    func portal<Content: View>(isPresented: Binding<Bool>, configs: PortalConfigs = .init(), @ViewBuilder content: @escaping () -> Content) -> some View {
        overlay { PortalReference(isPresented: isPresented, configs: configs, content: content) }
    }
}
