import SwiftUI

// MARK: - ContextMenuRoot

struct ContextMenuRoot: View, TracedView, SelectorHolder {
    class Selector: SelectorBase {
        @Selected({ global.contextMenu.menus }) var menus
    }

    @SelectorWrapper var selector

    var body: some View { trace {
        setupSelector {
            ZStack {
                ForEach(Array(selector.menus)) { ContextMenuView(data: $0) }
            }
        }
    } }
}

// MARK: - ContextMenuModifier

struct ContextMenuModifier: ViewModifier, SelectorHolder {
    let bounds: CGRect

    class Selector: SelectorBase {
        override var configs: SelectorConfigs { .init(syncNotify: true) }
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
    let data: ContextMenuData

    var equatableBy: some Equatable { data }

    var body: some View { trace {
        content
    } }

    // MARK: private

    @ViewBuilder private var content: some View {
        switch data {
        case .pathFocusedPart:
            FocusedPathSelectionMenu()
        case .focusedPath:
            FocusedPathMenu()
        case .focusedGroup:
            FocusedGroupMenu()
        case .selection:
            SelectionMenu()
        }
    }
}
