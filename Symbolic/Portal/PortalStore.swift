import SwiftUI

private let subtracer = tracer.tagged("PortalStore")

typealias PortalMap = OrderedMap<UUID, PortalData>

// MARK: - PortalStore

class PortalStore: Store {
    @Trackable var map = PortalMap()
    @Trackable var rootFrame: CGRect = .zero
}

private extension PortalStore {
    func update(portalMap: PortalMap) {
        update { $0(\._map, portalMap) }
    }

    func update(rootFrame: CGRect) {
        update { $0(\._rootFrame, rootFrame) }
    }
}

extension PortalStore {
    func register(configs: PortalConfigs = .init(), reference: CGRect, @ViewBuilder _ view: @escaping () -> any View) -> UUID {
        let portal = PortalData(configs: configs, view: AnyView(view()), reference: reference)
        let _r = subtracer.range("register \(portal.id) with \(configs) reference \(reference)"); defer { _r() }
        update(portalMap: map.cloned { $0[portal.id] = portal })
        return portal.id
    }

    func setReference(of id: UUID, _ frame: CGRect) {
        let _r = subtracer.range("set reference \(frame) of \(id)"); defer { _r() }
        update(portalMap: map.cloned { $0[id]?.reference = frame })
    }

    func setRootFrame(_ frame: CGRect) {
        let _r = subtracer.range("set root frame \(frame)"); defer { _r() }
        update(rootFrame: frame)
    }

    func deregister(id: UUID) {
        let _r = subtracer.range("deregister \(id)"); defer { _r() }
        update(portalMap: map.cloned { $0.removeValue(forKey: id) })
    }
}

// MARK: - PortalReference

struct PortalReference<Content: View>: View, SelectorHolder {
    @Binding var isPresented: Bool
    var configs: PortalConfigs = .init()
    @ViewBuilder var content: () -> Content

    class Selector: SelectorBase {
        @Selected({ global.portal.map }) var map
    }

    @SelectorWrapper var selector

    @State private var frame: CGRect = .zero
    @State private var portalId: UUID?

    private var deregistered: Bool {
        guard let portalId else { return false }
        return selector.map.value(key: portalId) == nil
    }

    var body: some View {
        setupSelector {
            if isPresented {
                Color.clear
                    .geometryReader { frame = $0.frame(in: .global) }
                    .onChange(of: deregistered) { _, deregistered in if deregistered { isPresented = false } }
                    .onChange(of: frame) { portalId.map { global.portal.setReference(of: $0, frame) } }
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
