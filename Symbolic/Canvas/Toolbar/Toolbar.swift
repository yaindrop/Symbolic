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

struct ToolbarModifier: ViewModifier, SelectorHolder {
    class Selector: SelectorBase {
        @Selected({ global.viewport.store.viewSize }) var viewSize
        @Selected({ global.toolbar.mode }) var toolbarMode
        @Selected({ global.document.undoable }) var undoable
    }

    @SelectorWrapper var selector

    func body(content: Content) -> some View {
        setupSelector {
            let _ = selector.viewSize // strange bug that toolbar is lost when window size changes, need to reset ids
            content.toolbar { toolbar }
        }
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent { tracer.range("CanvasView toolbar") { build {
        ToolbarItem(placement: .topBarLeading) { leading.id(UUID()) }
        ToolbarItem(placement: .principal) { principal.id(UUID()) }
        ToolbarItem(placement: .topBarTrailing) { trailing.id(UUID()) }
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
                Image(systemName: selector.toolbarMode.select != nil ? "rectangle.and.hand.point.up.left.fill" : "rectangle.and.hand.point.up.left")
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
            }
        }
    }

    private var trailing: some View {
        Button {
            global.document.undo()
        } label: {
            Image(systemName: "arrow.uturn.backward")
        }
        .disabled(!selector.undoable)
    }
}
