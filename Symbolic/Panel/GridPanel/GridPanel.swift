import SwiftUI

// MARK: - GridPanel

struct GridPanel: View, TracedView, SelectorHolder {
    class Selector: SelectorBase {
        @Selected(configs: .init(animation: .fast), { global.grid.grid }) var grid
    }

    @SelectorWrapper var selector

    @State private var gridCase: Grid.Case = .cartesian

    var body: some View { trace {
        setupSelector {
            content
                .onChange(of: gridCase) {
                    switch gridCase {
                    case .cartesian: global.grid.update(grid: .cartesian(.init(interval: 8)))
                    case .isometric: global.grid.update(grid: .isometric(.init(interval: 8, angle0: .degrees(30), angle1: .degrees(-30))))
                    case .radial: break
                    }
                }
        }
    } }
}

// MARK: private

extension GridPanel {
    @ViewBuilder private var content: some View {
        PanelBody(name: "Grid", maxHeight: 600) { _ in
            preview
            configs
        }
    }

    @ViewBuilder private var preview: some View {
        PanelSection(name: "Preview") {
            GridPreview()
        }
    }

    @ViewBuilder private var configs: some View {
        PanelSection(name: "Configs") {
            Picker("", selection: $gridCase) {
                Text("Cartesian").tag(Grid.Case.cartesian)
                Text("Isometric").tag(Grid.Case.isometric)
            }
            .pickerStyle(.segmented)
            .padding(12)
            switch selector.grid {
            case let .cartesian(grid): GridCartesianConfigs(grid: grid)
            case let .isometric(grid): GridIsometricConfigs(grid: grid)
            case .radial: EmptyView()
            }
        }
    }
}

// MARK: - GridPreview

private struct GridPreview: View, TracedView, SelectorHolder {
    class Selector: SelectorBase {
        @Selected(configs: .init(animation: .fast), { global.grid.grid }) var grid
    }

    @SelectorWrapper var selector

    @ThrottledState(configs: .init(duration: 1, leading: false)) private var viewport: SizedViewportInfo = .init(size: .zero, info: .init())

    @State private var size: CGSize = .zero

    var body: some View { trace {
        setupSelector {
            content
                .onChange(of: selector.grid, initial: true) {
                    let scale = size.width > 0 ? size.width / (5 * interval) : 1
                    viewport = .init(size: size, center: .zero, scale: scale)
                    if viewport.size == .zero {
                        _viewport.throttleEnd()
                    }
                }
                .animation(.fast, value: viewport)
        }
    } }
}

// MARK: private

private extension GridPreview {
    var interval: Scalar {
        switch selector.grid {
        case let .cartesian(grid):
            grid.interval != 0 ? grid.interval : 1
        case let .isometric(grid):
            grid.interval != 0 ? grid.interval : 1
        default: 1
        }
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

// MARK: - GridCartesianConfigs

private struct GridCartesianConfigs: View, TracedView {
    let grid: Grid.Cartesian

    @State private var interval: Scalar

    init(grid: Grid.Cartesian) {
        self.grid = grid
        interval = grid.interval
    }

    var body: some View { trace {
        content
            .onChange(of: interval) {
                global.grid.update(grid: .cartesian(.init(interval: interval)))
            }
    } }
}

// MARK: private

private extension GridCartesianConfigs {
    @ViewBuilder var content: some View {
        HStack {
            Text("Interval")
            Spacer()
            Slider(
                value: $interval,
                in: 2 ... 64,
                step: 1
            )
            Text("\(Int(grid.interval))")
        }
        .font(.callout)
        .padding(12)
    }
}

// MARK: - GridIsometricConfigs

private struct GridIsometricConfigs: View, TracedView {
    let grid: Grid.Isometric

    @State private var interval: Scalar
    @State private var angle0: Scalar
    @State private var angle1: Scalar

    init(grid: Grid.Isometric) {
        self.grid = grid
        interval = grid.interval
        angle0 = grid.angle0.degrees
        angle1 = grid.angle1.degrees
    }

    var body: some View { trace {
        content
            .onChange(of: EquatableTuple(interval, angle0, angle1)) {
                global.grid.update(grid: .isometric(.init(interval: interval, angle0: .degrees(angle0), angle1: .degrees(angle1))))
            }
    } }
}

// MARK: private

private extension GridIsometricConfigs {
    @ViewBuilder var content: some View {
        Group {
            HStack {
                Text("Interval")
                Spacer()
                Slider(
                    value: $interval,
                    in: 2 ... 64,
                    step: 1
                )
                Text("\(Int(grid.interval))")
            }
            .padding(12)
            HStack {
                Text("Angle 0")
                Spacer()
                Slider(
                    value: $angle0,
                    in: -90 ... 90,
                    step: 5
                )
                Text("\(grid.angle0.shortDescription)")
            }
            .padding(12)
            HStack {
                Text("Angle 1")
                Spacer()
                Slider(
                    value: $angle1,
                    in: -90 ... 90,
                    step: 5
                )
                Text("\(grid.angle1.shortDescription)")
            }
            .padding(12)
        }
        .font(.callout)
    }
}
