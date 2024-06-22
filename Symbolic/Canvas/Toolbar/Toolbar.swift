import SwiftUI

// MARK: - ToolbarMode

enum ToolbarMode: Equatable {
    struct Select: Equatable {
        var multiSelect = false
        var dragSelectLeaf = false
    }

    struct AddPath: Equatable {}

    case select(Select)
    case addPath(AddPath)

    var select: Select? { if case let .select(select) = self { select } else { nil }}
    var addPath: AddPath? { if case let .addPath(addPath) = self { addPath } else { nil }}
}

// MARK: - ToolbarStore

class ToolbarStore: Store {
    @Trackable var mode: ToolbarMode = .select(.init())
}

extension ToolbarStore {
    var multiSelect: Bool { mode.select?.multiSelect == true }

    func setMode(_ mode: ToolbarMode) {
        update { $0(\._mode, mode) }
    }
}

// MARK: - Toolbar

struct Toolbar: View, SelectorHolder {
    class Selector: SelectorBase {
        @Selected({ global.viewport.store.viewSize }) var viewSize
        @Selected({ global.toolbar.mode }) var toolbarMode
        @Selected({ global.document.undoable }) var undoable
    }

    @SelectorWrapper var selector

    var body: some View {
        setupSelector {
            content
        }
    }
}

// MARK: private

private extension Toolbar {
    var content: some View {
        ZStack {
            HStack {
                leading
                Spacer()
                trailing
            }
            HStack {
                Spacer()
                principal
                Spacer()
            }
        }
    }

    @ViewBuilder var documentMenu: some View {
        Text("Item 0")
        Divider()
        Text("Item 1")
    }

    var documentTitle: some View {
        HStack(spacing: 12) {
            Text("未命名2").font(.headline)
            Image(systemName: "chevron.down.circle.fill")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.label.opacity(0.5))
                .font(.body)
                .fontWeight(.black)
        }
        .tint(.label)
    }

    var leading: some View {
        ToolbarSection {
            ToolbarButton(systemName: "chevron.left") {
                global.root.update(showCanvas: false)
            }

            Menu { documentMenu } label: { documentTitle }
        }
    }

    @ViewBuilder var trailing: some View {
        ToolbarSection {
            PanelPopoverButton()

            ToolbarButton(systemName: "arrow.uturn.backward") {
                global.document.undo()
            }
            .disabled(!selector.undoable)
        }
    }

    var principal: some View {
        ToolbarSection {
            ToolbarButton(systemName: selector.toolbarMode.select != nil ? "rectangle.and.hand.point.up.left.fill" : "rectangle.and.hand.point.up.left") {
                global.toolbar.setMode(.select(.init()))
            }
            .overlay {
                if let select = selector.toolbarMode.select {
                    Menu {
                        Button(select.multiSelect ? "Disable multi-select" : "Tap to multi-select") {
                            var select = select
                            select.multiSelect.toggle()
                            global.toolbar.setMode(.select(select))
                        }
                        Button(select.dragSelectLeaf ? "Drag to select root" : "Drag to select leaf") {
                            var select = select
                            select.dragSelectLeaf.toggle()
                            global.toolbar.setMode(.select(select))
                        }
                    } label: {
                        Color.clear
                    }
                }
            }

            ToolbarButton(systemName: selector.toolbarMode.addPath != nil ? "plus.circle.fill" : "plus.circle") {
                global.toolbar.setMode(.addPath(.init()))
            }
        }
    }
}

private struct ToolbarSection<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(spacing: 12) { content() }
            .padding(6)
            .background(.ultraThinMaterial)
            .clipRounded(radius: 12)
            .shadow(color: .init(.sRGBLinear, white: 0, opacity: 0.2), radius: 6)
    }
}

private struct ToolbarButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title2)
                .frame(size: .init(squared: 36))
        }
    }
}

// MARK: - PanelPopoverButton

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

// MARK: private

private extension PanelPopoverButton {
    var content: some View {
        ToolbarButton(systemName: "list.dash.header.rectangle") {
            global.panel.togglePopover()
        }
        .geometryReader { global.panel.setPopoverButtonFrame($0.frame(in: .global)) }
        .if(selector.active && !selector.moving) {
            $0.tint(.systemBackground)
                .background(.blue)
                .clipRounded(radius: 6)
        }
        .if(selector.moving && !selector.hovering) {
            $0.overlay {
                RoundedRectangle(cornerRadius: 6).stroke(Color.invisibleSolid).shadow(color: .blue, radius: glowingRadius)
                    .allowsHitTesting(false)
            }
            .animatedValue($glowingRadius, from: 1, to: 6, .linear(duration: 0.5).repeatForever())
        }
        .if(selector.hovering) {
            $0.clipRounded(radius: 6, border: .blue, stroke: .init(lineWidth: 2))
        }
    }
}
