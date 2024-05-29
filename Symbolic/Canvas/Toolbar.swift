import Foundation
import SwiftUI

enum ToolbarMode {
    struct Select {
        var tapSelect = false
        var dragSelectLeaf = false
    }

    struct AddPath {}

    case select(Select)
    case addPath(AddPath)
}

class ToolbarStore: Store {
    @Trackable var mode: ToolbarMode = .select(.init())

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

    private var isToolbarSelect: Bool { if case .select = toolbarMode { true } else { false } }
    private var isToolbarAddPath: Bool { if case .addPath = toolbarMode { true } else { false } }

//    @State private var lastEdgeCase: PathEdge.Case = .line

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
                Image(systemName: isToolbarSelect ? "rectangle.and.hand.point.up.left.fill" : "rectangle.and.hand.point.up.left")
            }
            Button {
                global.toolbar.setMode(.addPath(.init()))
            } label: {
                Image(systemName: isToolbarAddPath ? "plus.circle.fill" : "plus.circle")
            }
//            .overlay {
//                Menu {
//                    Button("Arc", systemImage: "circle") {
//                        lastEdgeCase = .arc
//                        global.toolbar.setMode(.addPath(.init(edgeCase: .arc)))
//                    }
//                    .disabled(lastEdgeCase == .arc)
//                    Button("Bezier", systemImage: "point.bottomleft.forward.to.point.topright.scurvepath") {
//                        lastEdgeCase = .bezier
//                        global.toolbar.setMode(.addPath(.init(edgeCase: .bezier)))
//                    }
//                    .disabled(lastEdgeCase == .bezier)
//                    Button("Line", systemImage: "chart.xyaxis.line") {
//                        lastEdgeCase = .line
//                        global.toolbar.setMode(.addPath(.init(edgeCase: .line)))
//                    }
//                    .disabled(lastEdgeCase == .line)
//                } label: {
//                    Color.clear
//                }
//                .disabled(!isToolbarAddPath)
//            }
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
