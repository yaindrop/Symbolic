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
    @Environment(\.dismiss) var dismiss

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

    var leading: some View {
        HStack(spacing: 24) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .frame(size: .init(squared: 24))
            }

            Menu {
                Text("Item 0")
                Divider()
                Text("Item 1")
            } label: {
                HStack {
                    Text("未命名2").font(.headline)
                    Image(systemName: "chevron.down.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color.label.opacity(0.5))
                        .font(.footnote)
                        .fontWeight(.black)
                }
                .tint(.label)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipRounded(radius: 12)
        .shadow(color: .init(.sRGBLinear, white: 0, opacity: 0.2), radius: 6)
    }

    @ViewBuilder var trailing: some View {
        HStack(spacing: 24) {
            PanelPopoverButton()
                .font(.title2)
                .frame(size: .init(squared: 24))

            Button {
                global.document.undo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.title2)
                    .frame(size: .init(squared: 24))
            }
            .disabled(!selector.undoable)
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipRounded(radius: 12)
        .shadow(color: .init(.sRGBLinear, white: 0, opacity: 0.2), radius: 6)
    }

    var principal: some View {
        HStack(spacing: 24) {
            Button {
                global.toolbar.setMode(.select(.init()))
            } label: {
                Image(systemName: selector.toolbarMode.select != nil ? "rectangle.and.hand.point.up.left.fill" : "rectangle.and.hand.point.up.left")
                    .font(.title2)
                    .frame(size: .init(squared: 24))
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
            Button {
                global.toolbar.setMode(.addPath(.init()))
            } label: {
                Image(systemName: selector.toolbarMode.addPath != nil ? "plus.circle.fill" : "plus.circle")
                    .font(.title2)
                    .frame(size: .init(squared: 24))
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipRounded(radius: 12)
        .shadow(color: .init(.sRGBLinear, white: 0, opacity: 0.2), radius: 6)
    }
}
