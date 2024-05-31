import Foundation
import SwiftUI

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

class ToolbarStore: Store {
    @Trackable var mode: ToolbarMode = .select(.init())

    var multiSelect: Bool { mode.select?.multiSelect == true }

    func setMode(_ mode: ToolbarMode) {
        update { $0(\._mode, mode) }
    }
}

struct ToolbarModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.toolbar { toolbar }
    }

    @Selected private var toolbarMode = global.toolbar.mode
    @Selected private var undoable = global.document.undoable

    @ToolbarContentBuilder private var toolbar: some ToolbarContent { tracer.range("CanvasView toolbar") { build {
        ToolbarItem(placement: .topBarLeading) { leading }
        ToolbarItem(placement: .principal) { principal }
        ToolbarItem(placement: .topBarTrailing) { trailing }
    }}}

    private var leading: some View {
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

    private var principal: some View {
        HStack {
            Button {
                global.toolbar.setMode(.select(.init()))
            } label: {
                Image(systemName: toolbarMode.select != nil ? "rectangle.and.hand.point.up.left.fill" : "rectangle.and.hand.point.up.left")
            }
            .overlay {
                if let select = toolbarMode.select {
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
                Image(systemName: toolbarMode.addPath != nil ? "plus.circle.fill" : "plus.circle")
            }
        }
    }

    private var trailing: some View {
        Button {
            global.document.undo()
        } label: {
            Image(systemName: "arrow.uturn.backward")
        }
        .disabled(!undoable)
    }
}
