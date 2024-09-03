import SwiftUI

// MARK: - PanelPopoverSectionView

struct PanelPopoverSectionView: View, TracedView {
    let panel: PanelData

    var body: some View { trace {
        content
            .id(panel.id)

    } }
}

// MARK: private

private extension PanelPopoverSectionView {
    var content: some View {
        Section(header: sectionTitle) {
            VStack(spacing: 12) {
                Memo {
                    panel.view
                }
            }
            .padding(.leading, 24)
            .padding(.trailing.union(.bottom), 12)
            .environment(\.panelId, panel.id)
        }
    }

    var sectionTitle: some View {
        HStack {
            Text(panel.name)
                .font(.title2)
            Spacer()
            Button {
                global.panel.setFloating(id: panel.id)
            } label: {
                Image(systemName: "rectangle.inset.topright.filled")
                    .tint(.label)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipRounded(radius: 12)
        .padding(12)
    }
}

// MARK: - PanelPopover

struct PanelPopover: View, SelectorHolder {
    class Selector: SelectorBase {
        override var configs: SelectorConfigs { .syncNotify }
        @Selected({ global.viewport.viewSize }) var viewSize
        @Selected({ global.panel.popoverPanels }) var popoverPanels
        @Selected(configs: .init(animation: .faster), { global.panel.popoverActive && global.panel.moving == nil }) var visible
    }

    @SelectorWrapper var selector

    @StateObject private var scrollViewModel = ManagedScrollViewModel()

    @State private var scrollFrame: CGRect = .zero

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
            .environment(\.panelScrollFrame, scrollFrame)
        }
        .scrollBounceBehavior(.basedOnSize, axes: [.vertical])
        .frame(maxWidth: .infinity, maxHeight: selector.viewSize.height - 240)
        .fixedSize(horizontal: false, vertical: true)
        .geometryReader { scrollFrame = $0.frame(in: .global) }
    }

    @ViewBuilder var panels: some View {
        if selector.popoverPanels.isEmpty {
            Text("No panels")
                .frame(maxWidth: .infinity, minHeight: 120)
                .padding()
        }
        ForEach(selector.popoverPanels) {
            PanelPopoverSectionView(panel: $0)
        }
    }

    @ViewBuilder var settings: some View {
        EmptyView()
    }
}
