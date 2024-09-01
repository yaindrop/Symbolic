import SwiftUI

// MARK: - ContextMenuStore

class ContextMenuStore: Store {
    @Trackable var hidden: Bool = false
}

extension ContextMenuStore {
    func setHidden(_ hidden: Bool) {
        update { $0(\._hidden, hidden) }
    }
}

// MARK: - ContextMenuType

enum ContextMenuType: SelfIdentifiable, CaseIterable {
    case pathFocusedPart
    case focusedPath
    case focusedGroup
    case selection
    case focusedSymbol
    case symbolSelection
}

// MARK: - ContextMenuRoot

struct ContextMenuRoot: View, TracedView, SelectorHolder {
    class Selector: SelectorBase {
        @Selected(configs: .syncNotify, { global.viewport.sizedInfo }) var viewport
        @Selected({ global.contextMenu.hidden }) var hidden
    }

    @SelectorWrapper var selector

    var body: some View { trace {
        setupSelector {
            AnimatableReader(selector.viewport) {
                ZStack {
                    ForEach(Array(ContextMenuType.allCases)) { ContextMenuView(type: $0) }
                        .opacity(selector.hidden ? 0 : 1)
                        .animation(.fast, value: selector.hidden)
                }
                .environment(\.sizedViewport, $0)
            }
        }
    } }
}

// MARK: - ContextMenuModifier

struct ContextMenuModifier: ViewModifier, SelectorHolder {
    let bounds: CGRect

    class Selector: SelectorBase {
        override var configs: SelectorConfigs { .syncNotify }
        @Selected({ global.panel.rootFrame }) var rootFrame
    }

    @SelectorWrapper var selector

    @State private var size: CGSize = .zero

    private var menuBox: CGRect {
        let menuAlign: PlaneOuterAlign = bounds.midY > CGRect(selector.rootFrame).midY ? .topCenter : .bottomCenter
        return bounds.alignedBox(at: menuAlign, size: size, gap: .init(squared: 12)).clamped(by: CGRect(selector.rootFrame).inset(by: 12))
    }

    func body(content: Content) -> some View {
        setupSelector {
            content
                .padding(12)
                .background(.regularMaterial)
                .fixedSize()
                .sizeReader { size = $0 }
                .clipRounded(radius: size.height / 2)
                .position(menuBox.center)
        }
    }
}

extension View {
    func contextMenu(bounds: CGRect) -> some View {
        modifier(ContextMenuModifier(bounds: bounds))
    }
}

// MARK: - ContextMenuView

struct ContextMenuView: View, TracedView, EquatableBy {
    let type: ContextMenuType

    var equatableBy: some Equatable { type }

    var body: some View { trace {
        content
    } }

    // MARK: private

    @ViewBuilder private var content: some View {
        switch type {
        case .pathFocusedPart:
            FocusedPathSelectionMenu()
        case .focusedPath:
            FocusedPathMenu()
        case .focusedGroup:
            FocusedGroupMenu()
        case .selection:
            SelectionMenu()
        case .focusedSymbol:
            FocusedSymbolMenu()
        case .symbolSelection: EmptyView()
        }
    }
}
