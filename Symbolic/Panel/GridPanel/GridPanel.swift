import SwiftUI

// MARK: - GridPanel

struct GridPanel: View, TracedView, SelectorHolder {
    class Selector: SelectorBase {
        @Selected(configs: .init(animation: .fast), { global.grid.active }) var grid
        @Selected(configs: .init(animation: .fast), { global.grid.gridStack }) var gridStack
        @Selected(configs: .init(animation: .fast), { global.grid.activeIndex }) var activeIndex
    }

    @SelectorWrapper var selector

    @State private var index = 0

    @State private var tintColor = Color.red

    @State private var gridCase: Grid.Case = .cartesian

    var body: some View { trace {
        setupSelector {
            content
                .onChange(of: selector.activeIndex, initial: true) {
                    index = selector.activeIndex
                }
                .onChange(of: selector.grid.tintColor, initial: true) {
                    tintColor = selector.grid.tintColor
                }
                .onChange(of: selector.grid.case, initial: true) {
                    gridCase = selector.grid.case
                }
                .onChange(of: index) {
                    guard index != selector.activeIndex else { return }
                    global.grid.setActive(index)
                }
                .onChange(of: tintColor) {
                    guard tintColor != selector.grid.tintColor else { return }
                    var grid = selector.grid
                    grid.tintColor = tintColor
                    global.grid.update(grid: grid)
                }
                .onChange(of: gridCase) {
                    guard gridCase != selector.grid.case else { return }
                    var grid = selector.grid
                    switch gridCase {
                    case .cartesian: grid.kind = .cartesian(.init(interval: 8))
                    case .isometric: grid.kind = .isometric(.init(interval: 8, angle0: .degrees(30), angle1: .degrees(-30)))
                    case .radial: break
                    }
                    global.grid.update(grid: grid)
                }
        }
    } }
}

// MARK: private

extension GridPanel {
    @ViewBuilder private var content: some View {
        PanelBody(name: "Grid", maxHeight: 600) { _ in
            preview
            tabs
            configs
        }
    }

    @ViewBuilder private var tabs: some View {
        if selector.gridStack.count > 1 {
            HStack {
                Picker("", selection: $index) {
                    Text("Primary").tag(0)
                    Text("Secondary").tag(1)
                    if selector.gridStack.count > 2 {
                        Text("Tertiary").tag(2)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    @ViewBuilder private var preview: some View {
        PanelSection(name: "Preview") {
            GridPreview(grid: selector.grid)
        }
    }

    @ViewBuilder private var configs: some View {
        PanelSection(name: "Configs") {
            HStack {
                Text("Tint Color")
                Spacer()
                ColorPicker("", selection: $tintColor)
            }
            .font(.callout)
            .padding(12)

            Divider()
                .padding(.leading, 12)

            HStack {
                Text("Type")
                Spacer()
                Picker("Type", selection: $gridCase) {
                    Text("Cartesian").tag(Grid.Case.cartesian)
                    Text("Isometric").tag(Grid.Case.isometric)
                    Text("Radial").tag(Grid.Case.radial)
                }
            }
            .font(.callout)
            .padding(12)

            Divider()
                .padding(.leading, 12)

            switch selector.grid.kind {
            case let .cartesian(grid): GridCartesianConfigs(grid: grid)
            case let .isometric(grid): GridIsometricConfigs(grid: grid)
            case .radial: EmptyView()
            }

            Divider()
                .padding(.leading, 12)

            HStack {
                Button(role: .destructive) {
                    global.grid.delete()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonBorderShape(.capsule)
                .buttonStyle(.bordered)
                .disabled(selector.gridStack.count == 1)
                Spacer()
                Button {
                    global.grid.add()
                } label: {
                    Image(systemName: "plus")
                }
                .buttonBorderShape(.capsule)
                .buttonStyle(.bordered)
                .disabled(selector.gridStack.count == 3)
            }
            .padding(12)
        }
    }
}

// MARK: - GridPreview

private struct GridPreview: View, TracedView {
    let grid: Grid

    @ThrottledState(configs: .init(duration: 1, leading: false)) private var viewport: SizedViewportInfo = .init(size: .zero, info: .init())

    @State private var size: CGSize = .zero

    var body: some View { trace {
        content
            .onChange(of: grid, initial: true) {
                let scale = size.width > 0 ? size.width / (5 * interval) : 1
                viewport = .init(size: size, center: .zero, scale: scale)
                if viewport.size == .zero {
                    _viewport.throttleEnd()
                }
            }
            .animation(.fast, value: viewport)

    } }
}

// MARK: private

private extension GridPreview {
    var interval: Scalar {
        switch grid.kind {
        case let .cartesian(grid):
            grid.interval != 0 ? grid.interval : 1
        case let .isometric(grid):
            grid.interval != 0 ? grid.interval : 1
        default: 1
        }
    }

    @ViewBuilder var gridView: some View {
        AnimatableReader(viewport) { viewport in
            switch grid.kind {
            case let .cartesian(grid):
                AnimatableReader(grid) {
                    GridView(grid: .init(kind: .cartesian($0)), viewport: viewport, color: self.grid.tintColor, type: .preview)
                }
            case let .isometric(grid):
                AnimatableReader(grid) {
                    GridView(grid: .init(kind: .isometric($0)), viewport: viewport, color: self.grid.tintColor, type: .preview)
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
                var grid = global.grid.active
                grid.kind = .cartesian(.init(interval: interval))
                global.grid.update(grid: grid)
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
                var grid = global.grid.active
                grid.kind = .isometric(.init(interval: interval, angle0: .degrees(angle0), angle1: .degrees(angle1)))
                global.grid.update(grid: grid)
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

            Divider()

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

            Divider()

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
