import Combine
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

    var body: some View { trace {
        setupSelector {
            content
                .onChange(of: index) {
                    guard index != selector.activeIndex else { return }
                    global.grid.setActive(index)
                }
                .bind(selector.activeIndex, to: $index)
                .environmentObject(ViewModel())
        }
    } }
}

// MARK: private

extension GridPanel {
    @ViewBuilder private var content: some View {
        PanelBody(name: "Grid", maxHeight: 600) { _ in
            tabs
            preview
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
            Preview(grid: selector.grid)
        }
    }

    @ViewBuilder private var configs: some View {
        PanelSection(name: "Configs") {
            Configs(grid: selector.grid)

            ConfigsDivider()

            switch selector.grid.kind {
            case let .cartesian(grid): CartesianConfigs(grid: grid)
            case let .isometric(grid): IsometricConfigs(grid: grid)
            case .radial: EmptyView()
            }

            ConfigsDivider()

            ConfigsRow {
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
        }
    }
}

// MARK: - components

private extension GridPanel {
    class ViewModel: ObservableObject {
        @State var intervalCommit = PassthroughSubject<Void, Never>()
    }

    struct ConfigsRow<Content: View>: View {
        var label: String? = nil
        @ViewBuilder let content: () -> Content

        var body: some View {
            HStack {
                if let label {
                    Text(label)
                        .font(.callout)
                    Spacer()
                }
                content()
            }
            .frame(height: 36)
            .padding(size: .init(12, 6))
        }
    }

    struct ConfigsDivider: View {
        var body: some View {
            Divider()
                .padding(.leading, 12)
        }
    }
}

// MARK: - Preview

private extension GridPanel {
    struct Preview: View, TracedView {
        @EnvironmentObject private var viewModel: GridPanel.ViewModel

        let grid: Grid

        @DelayedState(configs: .init(duration: 0.5)) private var viewport: SizedViewportInfo = .init(size: .zero, info: .init())

        @State private var size: CGSize = .zero

        var body: some View { trace {
            content
                .onChange(of: grid, initial: true) { updateViewport() }
                .animation(.fast, value: viewport)
                .onReceive(viewModel.intervalCommit) { _viewport.delayEnd() }
        } }
    }
}

// MARK: private

private extension GridPanel.Preview {
    func updateViewport() {
        let scale = size.width > 0 ? size.width / (7 * interval) : 1
        viewport = .init(size: size, center: .zero, scale: scale)
        if viewport.size == .zero {
            _viewport.delayEnd()
        }
    }

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
            .aspectRatio(3 / 2, contentMode: .fill)
            .sizeReader { size = $0 }
            .clipped()
    }
}

// MARK: - Configs

private extension GridPanel {
    struct Configs: View, TracedView {
        let grid: Grid

        @State private var tintColor = Color.red

        @State private var gridCase: Grid.Case = .cartesian

        init(grid: Grid) {
            self.grid = grid
            tintColor = grid.tintColor
            gridCase = grid.case
        }

        var body: some View { trace {
            content
                .onChange(of: tintColor) {
                    guard tintColor != grid.tintColor else { return }
                    var grid = grid
                    grid.tintColor = tintColor
                    global.grid.update(grid: grid)
                }
                .onChange(of: gridCase) {
                    guard gridCase != grid.case else { return }
                    var grid = grid
                    switch gridCase {
                    case .cartesian: grid.kind = .cartesian(.init(interval: 8))
                    case .isometric: grid.kind = .isometric(.init(interval: 8, angle0: .degrees(30), angle1: .degrees(-30)))
                    case .radial: break
                    }
                    global.grid.update(grid: grid)
                }
                .bind(grid.tintColor, to: $tintColor)
                .bind(grid.case, to: $gridCase)
        } }
    }
}

private extension GridPanel.Configs {
    @ViewBuilder var content: some View {
        GridPanel.ConfigsRow(label: "Color") {
            ColorPicker("", selection: $tintColor)
        }

        GridPanel.ConfigsDivider()

        GridPanel.ConfigsRow(label: "Type") {
            Picker("", selection: $gridCase) {
                Text("Cartesian").tag(Grid.Case.cartesian)
                Text("Isometric").tag(Grid.Case.isometric)
                Text("Radial").tag(Grid.Case.radial)
            }
        }
    }
}

// MARK: - CartesianConfigs

private extension GridPanel {
    struct CartesianConfigs: View, TracedView {
        let grid: Grid.Cartesian

        @EnvironmentObject private var viewModel: GridPanel.ViewModel

        @State private var interval: Scalar

        init(grid: Grid.Cartesian) {
            self.grid = grid
            interval = grid.interval
        }

        var body: some View { trace {
            content
                .onChange(of: interval) { updateGrid() }
                .bind(grid.interval, to: $interval)
        } }
    }
}

// MARK: private

private extension GridPanel.CartesianConfigs {
    func updateGrid() {
        var grid = global.grid.active
        grid.kind = .cartesian(.init(interval: interval))
        global.grid.update(grid: grid)
    }

    @ViewBuilder var content: some View {
        GridPanel.ConfigsRow(label: "Interval") {
            Slider(
                value: $interval,
                in: 2 ... 64,
                step: 1,
                onEditingChanged: { _ in viewModel.intervalCommit.send() }
            )
            Text("\(Int(grid.interval))")
                .font(.callout)
        }
    }
}

// MARK: - IsometricConfigs

private extension GridPanel {
    struct IsometricConfigs: View, TracedView {
        let grid: Grid.Isometric

        @EnvironmentObject private var viewModel: GridPanel.ViewModel

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
                .onChange(of: EquatableTuple(interval, angle0, angle1)) { updateGrid() }
                .bind(grid.interval, to: $interval)
                .bind(grid.angle0, to: $angle0) { $0.degrees }
                .bind(grid.angle1, to: $angle1) { $0.degrees }
        } }
    }
}

// MARK: private

private extension GridPanel.IsometricConfigs {
    func updateGrid() {
        var grid = global.grid.active
        grid.kind = .isometric(.init(interval: interval, angle0: .degrees(angle0), angle1: .degrees(angle1)))
        global.grid.update(grid: grid)
    }

    @ViewBuilder var content: some View {
        GridPanel.ConfigsRow(label: "Interval") {
            Slider(
                value: $interval,
                in: 2 ... 64,
                step: 1,
                onEditingChanged: { _ in viewModel.intervalCommit.send() }
            )
            Text("\(Int(grid.interval))")
                .font(.callout)
        }

        GridPanel.ConfigsDivider()

        GridPanel.ConfigsRow(label: "Angle 0") {
            Slider(
                value: $angle0,
                in: -90 ... 90,
                step: 5
            )
            Text("\(grid.angle0.shortDescription)")
                .font(.callout)
        }

        GridPanel.ConfigsDivider()

        GridPanel.ConfigsRow(label: "Angle 1") {
            Slider(
                value: $angle1,
                in: -90 ... 90,
                step: 5
            )
            Text("\(grid.angle1.shortDescription)")
                .font(.callout)
        }
    }
}
