import SwiftUI

// MARK: - GridPanel

struct GridPanel: View, TracedView, SelectorHolder {
    class Selector: SelectorBase {
        @Selected({ global.document.activeDocument }) var document
    }

    @SelectorWrapper var selector

    @StateObject private var scrollViewModel = ManagedScrollViewModel()

    @State private var sliderValue: Scalar = 8
    @ThrottledState(configs: .init(duration: 0.5, leading: false)) private var cellSize: Scalar = 8

    var body: some View { trace {
        setupSelector {
            content
                .onChange(of: sliderValue) { cellSize = sliderValue }
                .animation(.normal, value: cellSize)
                .onChange(of: cellSize) {
                    withAnimation {
                        global.grid.update(grid: .cartesian(.init(cellSize: cellSize)))
                    }
                }
        }
    } }
}

// MARK: private

extension GridPanel {
    @ViewBuilder private var content: some View {
        PanelBody(name: "Grid", maxHeight: 400) { _ in
            events
        }
    }

    @ViewBuilder private var events: some View {
        PanelSection(name: "Preview") {
            GridPreview(grid: .init(cellSize: cellSize))
        }
        PanelSection(name: "Configs") {
            HStack {
                Text("Cell Size")
                Spacer()
                Slider(
                    value: $sliderValue,
                    in: 2 ... 64,
                    step: 1,
                    onEditingChanged: { if !$0 { _cellSize.throttleEnd() }}
                )
                Text("\(Int(sliderValue))")
            }
            .padding(12)
        }
    }
}

struct GridPreview: View, TracedView, SelectorHolder {
    let grid: Grid.Cartesian

    class Selector: SelectorBase {
        @Selected({ global.grid.gridStack }) var document
    }

    @SelectorWrapper var selector

    @State private var size: CGSize = .zero

    var body: some View { trace {
        setupSelector {
            content
        }
    } }
}

extension GridPreview {
    var viewport: SizedViewportInfo {
        let scale = size.width > 0 ? size.width / 5 / grid.cellSize : 1
        return .init(size: size, center: .zero, scale: scale)
    }

    @ViewBuilder private var content: some View {
        AnimatableReader(viewport) {
            CartesianGridView(grid: grid, viewport: $0, color: .red, type: .preview)
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fill)
                .sizeReader { size = $0 }
                .clipped()
        }
    }
}
