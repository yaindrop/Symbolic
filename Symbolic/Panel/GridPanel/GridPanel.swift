import SwiftUI

// MARK: - GridPanel

struct GridPanel: View, TracedView, SelectorHolder {
    class Selector: SelectorBase {
        @Selected(configs: .init(animation: .fast), { global.grid.grid }) var grid
    }

    @SelectorWrapper var selector

    @StateObject private var scrollViewModel = ManagedScrollViewModel()

    @State private var sliderValue: Scalar = 8
    @ThrottledState(configs: .init(duration: 0.5, leading: false)) private var cellSize: Scalar = 8

    @State private var angle0Value: Scalar = 30
    @State private var angle1Value: Scalar = -30

    var body: some View { trace {
        setupSelector {
            content
                .onChange(of: sliderValue) { cellSize = sliderValue }
                .onChange(of: cellSize) {
//                    global.grid.update(grid: .cartesian(.init(cellSize: cellSize)))
                    global.grid.update(grid: .isometric(.init(interval: cellSize, angle0: .degrees(angle0Value), angle1: .degrees(angle1Value))))
                }
                .onChange(of: angle0Value) {
                    global.grid.update(grid: .isometric(.init(interval: cellSize, angle0: .degrees(angle0Value), angle1: .degrees(angle1Value))))
                }
                .onChange(of: angle1Value) {
                    global.grid.update(grid: .isometric(.init(interval: cellSize, angle0: .degrees(angle0Value), angle1: .degrees(angle1Value))))
                }
        }
    } }
}

// MARK: private

extension GridPanel {
    @ViewBuilder private var content: some View {
        PanelBody(name: "Grid", maxHeight: 600) { _ in
            events
        }
    }

    @ViewBuilder private var events: some View {
        PanelSection(name: "Preview") {
            GridPreview()
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
            HStack {
                Text("Angle0")
                Spacer()
                Slider(
                    value: $angle0Value,
                    in: -90 ... 90,
                    step: 5
                )
                Text("\(Int(angle0Value))")
            }
            .padding(12)
            HStack {
                Text("Angle1")
                Spacer()
                Slider(
                    value: $angle1Value,
                    in: -90 ... 90,
                    step: 5
                )
                Text("\(Int(angle1Value))")
            }
            .padding(12)
        }
    }
}

struct GridPreview: View, TracedView, SelectorHolder {
    class Selector: SelectorBase {
        @Selected(configs: .init(animation: .fast), { global.grid.grid }) var grid
    }

    @SelectorWrapper var selector

    @State private var size: CGSize = .zero

    var body: some View { trace {
        setupSelector {
            content
                .animation(.fast, value: viewport)
        }
    } }
}

extension GridPreview {
    var cellSize: Scalar {
        switch selector.grid {
        case let .cartesian(grid):
            grid.interval != 0 ? grid.interval : 1
        case let .isometric(grid):
            grid.interval != 0 ? grid.interval : 1
        default: 1
        }
    }

    var viewport: SizedViewportInfo {
        let scale = size.width > 0 ? size.width / (5 * cellSize) : 1
        return .init(size: size, center: .zero, scale: scale)
    }

    @ViewBuilder var gridView: some View {
        AnimatableReader(viewport) { viewport in
            switch selector.grid {
            case let .cartesian(grid):
                GridView(grid: .cartesian(grid), viewport: viewport, color: .red, type: .preview)
            case let .isometric(grid):
                AnimatableReader(grid) {
                    GridView(grid: .isometric(.init(interval: grid.interval, angle0: $0.angle0, angle1: $0.angle1)), viewport: viewport, color: .red, type: .preview)
                }
            default: EmptyView()
            }
        }
    }

    @ViewBuilder private var content: some View {
        gridView
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fill)
            .sizeReader { size = $0 }
            .clipped()
    }
}
