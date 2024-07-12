import SwiftUI

// MARK: - PanelPopover

struct PanelPopover: View, SelectorHolder {
    class Selector: SelectorBase {
        override var configs: SelectorConfigs { .init(syncNotify: true) }
        @Selected(configs: .init(animation: .faster), { global.panel.popoverActive && global.panel.movingPanelMap.isEmpty }) var visible
        @Selected({ global.viewport.viewSize }) var viewSize
        @Selected({ global.panel.popoverPanels }) var popoverPanels
    }

    @SelectorWrapper var selector

    @StateObject private var scrollViewModel = ManagedScrollViewModel()

    @State private var isSettings = false

    var body: some View {
        setupSelector {
            content
        }
    }
}

// MARK: private

private extension PanelPopover {
    @ViewBuilder var content: some View {
        if selector.visible {
            VStack(spacing: 0) {
                tab
                scrollView
            }
            .frame(width: 320)
            .background(.ultraThinMaterial)
            .clipRounded(radius: 12)
            .shadow(color: .init(.sRGBLinear, white: 0, opacity: 0.1), radius: 6, x: -3, y: 3)
            .padding(12)
            .innerAligned(.topTrailing)
        }
    }

    var tab: some View {
        Picker("", selection: $isSettings.animation()) {
            Text("Panels").tag(false)
            Text("Settings").tag(true)
        }
        .pickerStyle(.segmented)
        .padding(12)
    }

    var scrollView: some View {
        ManagedScrollView(model: scrollViewModel) { proxy in
            VStack(spacing: 0) {
                if isSettings {
                    settings
                } else {
                    panels
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .environment(\.panelScrollProxy, proxy)
        }
        .scrollBounceBehavior(.basedOnSize, axes: [.vertical])
        .frame(maxWidth: .infinity, maxHeight: selector.viewSize.height - 240)
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder var panels: some View {
        if selector.popoverPanels.isEmpty {
            Text("No panels")
                .frame(maxWidth: .infinity, minHeight: 120)
                .padding()
        }
        ForEach(selector.popoverPanels) {
            PanelView(panel: $0)
        }
    }

    @ViewBuilder var settings: some View {
        EmptyView()
    }
}
