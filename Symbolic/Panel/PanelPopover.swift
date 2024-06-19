import SwiftUI

struct PanelPopoverButton: View, SelectorHolder {
    class Selector: SelectorBase {
        @Selected({ global.panel.popoverActive }) var active
        @Selected({ !global.panel.movingPanelMap.isEmpty }) var moving
        @Selected({ global.panel.popoverButtonHovering }) var hovering
    }

    @SelectorWrapper var selector

    @State private var glowingRadius: Scalar = 0

    var body: some View {
        setupSelector {
            content
        }
    }
}

private extension PanelPopoverButton {
    var content: some View {
        Button {
            global.panel.togglePopover()
        } label: {
            Image(systemName: "list.dash.header.rectangle")
                .padding(6)
                .geometryReader { global.panel.setPopoverButtonFrame($0.frame(in: .global)) }
                .if(selector.active && !selector.moving) {
                    $0.tint(.systemBackground)
                        .background(.blue)
                        .clipRounded(radius: 6)
                }
                .if(selector.moving && !selector.hovering) {
                    $0.overlay { RoundedRectangle(cornerRadius: 6).stroke(Color.invisibleSolid).shadow(color: .blue, radius: glowingRadius) }
                        .animatedValue($glowingRadius, from: 2, to: 12, .linear(duration: 0.5).repeatForever())
                }
                .if(selector.hovering) {
                    $0.clipRounded(radius: 6, border: .blue, stroke: .init(lineWidth: 2))
                }
        }
    }
}

struct PanelPopover: View, SelectorHolder {
    class Selector: SelectorBase {
        override var syncUpdate: Bool { true }
        @Selected(animation: .fast, { global.panel.popoverActive && global.panel.movingPanelMap.isEmpty }) var visible
        @Selected({ global.viewport.viewSize }) var viewSize
        @Selected({ global.panel.popoverPanels }) var popoverPanels
    }

    @SelectorWrapper var selector

    @State private var isSettings = false

    var body: some View {
        setupSelector {
            content
        }
    }

    @ViewBuilder var content: some View {
        if selector.visible {
            ScrollView {
                Picker("", selection: $isSettings.animation()) {
                    Text("Panels").tag(false)
                    Text("Settings").tag(true)
                }
                .pickerStyle(.segmented)
                .fixedSize(horizontal: false, vertical: true)
                .padding()
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    if isSettings {
                        settings
                    } else {
                        panels
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize, axes: [.vertical])
            .frame(maxHeight: selector.viewSize.height - 64)
            .fixedSize(horizontal: false, vertical: true)
            .frame(width: 320)
            .background(.ultraThinMaterial)
            .clipRounded(radius: 12)
            .shadow(color: .init(.sRGBLinear, white: 0, opacity: 0.1), radius: 6, x: -3, y: 3)
            .padding(12)
            .innerAligned(.topTrailing)
        }
    }

    @ViewBuilder var panels: some View {
        if selector.popoverPanels.isEmpty {
            Text("No panels")
                .frame(maxWidth: .infinity, minHeight: 120)
                .padding()
        }
        ForEach(selector.popoverPanels) {
            $0.view
                .environment(\.panelId, $0.id)
        }
    }

    @ViewBuilder var settings: some View {
        EmptyView()
    }
}
