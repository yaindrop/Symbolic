import SwiftUI

// MARK: - Configs

extension GridPanel {
    struct Configs: View, TracedView, SelectorHolder {
        class Selector: SelectorBase {
            @Selected(configs: .init(animation: .fast), { global.activeSymbol.grids }) var gridStack
            @Selected(configs: .init(animation: .fast), { global.activeSymbol.grid }) var grid
        }

        @SelectorWrapper var selector

        @State private var tintColor = UIColor.red.cgColor

        @State private var gridCase: Grid.Case = .cartesian

        var body: some View { trace {
            setupSelector {
                if let grid = selector.grid {
                    content
                        .onChange(of: tintColor) {
                            guard tintColor != grid.tintColor else { return }
                            var grid = grid
                            grid.tintColor = tintColor
                            //                        global.grid.update(grid: grid)
                        }
                        .onChange(of: gridCase) {
                            guard gridCase != grid.case else { return }
                            var grid = grid
                            switch gridCase {
                            case .cartesian: grid.kind = .cartesian(.init(interval: 8))
                            case .isometric: grid.kind = .isometric(.init(interval: 8, angle0: .degrees(30), angle1: .degrees(-30)))
                            case .radial: break
                            }
                            //                        global.grid.update(grid: grid)
                        }
                        .bind(grid.tintColor, to: $tintColor)
                        .bind(grid.case, to: $gridCase)
                }
            }
        } }
    }
}

private extension GridPanel.Configs {
    @ViewBuilder var content: some View {
        colorRow
        ContextualDivider()
        typeRow
        ContextualDivider()
        kindConfigs
        ContextualDivider()
        editRow
    }

    var colorRow: some View {
        ContextualRow(label: "Color") {
            ColorPicker("", selection: $tintColor)
        }
    }

    var typeRow: some View {
        ContextualRow(label: "Type") {
            Picker("", selection: $gridCase) {
                Text("Cartesian").tag(Grid.Case.cartesian)
                Text("Isometric").tag(Grid.Case.isometric)
                Text("Radial").tag(Grid.Case.radial)
            }
        }
    }

    @ViewBuilder var kindConfigs: some View {
        if let grid = selector.grid {
            switch grid.kind {
            case let .cartesian(grid): Cartesian(grid: grid)
            case let .isometric(grid): Isometric(grid: grid)
            case .radial: EmptyView()
            }
        }
    }

    var editRow: some View {
        ContextualRow {
            Button(role: .destructive) {
//                global.grid.delete()
            } label: {
                Image(systemName: "trash")
            }
            .buttonBorderShape(.capsule)
            .buttonStyle(.bordered)
            .disabled(selector.gridStack.count == 1)
            Spacer()
            Button {
//                global.grid.add()
            } label: {
                Image(systemName: "plus")
            }
            .buttonBorderShape(.capsule)
            .buttonStyle(.bordered)
            .disabled(selector.gridStack.count == 3)
        }
    }
}

// MARK: - CartesianConfigs

private extension GridPanel.Configs {
    struct Cartesian: View, TracedView {
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

private extension GridPanel.Configs.Cartesian {
    func updateGrid() {
//        var grid = global.grid.active
//        grid.kind = .cartesian(.init(interval: interval))
//        global.grid.update(grid: grid)
    }

    @ViewBuilder var content: some View {
        intervalRow
    }

    var intervalRow: some View {
        ContextualRow(label: "Interval") {
            Slider(
                value: $interval,
                in: 2 ... 64,
                step: 1,
                onEditingChanged: { _ in viewModel.intervalCommit.send() }
            )
            Text("\(Int(grid.interval))")
                .contextualFont()
        }
    }
}

// MARK: - IsometricConfigs

private extension GridPanel.Configs {
    struct Isometric: View, TracedView {
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

private extension GridPanel.Configs.Isometric {
    func updateGrid() {
//        var grid = global.grid.active
//        grid.kind = .isometric(.init(interval: interval, angle0: .degrees(angle0), angle1: .degrees(angle1)))
//        global.grid.update(grid: grid)
    }

    @ViewBuilder var content: some View {
        intervalRow
        ContextualDivider()
        angle0Row
        ContextualDivider()
        angle1Row
    }

    var intervalRow: some View {
        ContextualRow(label: "Interval") {
            Slider(
                value: $interval,
                in: 2 ... 64,
                step: 1,
                onEditingChanged: { _ in viewModel.intervalCommit.send() }
            )
            Text("\(Int(grid.interval))")
                .contextualFont()
        }
    }

    var angle0Row: some View {
        ContextualRow(label: "Angle 0") {
            Slider(
                value: $angle0,
                in: -90 ... 90,
                step: 5
            )
            Text("\(grid.angle0.shortDescription)")
                .contextualFont()
        }
    }

    var angle1Row: some View {
        ContextualRow(label: "Angle 1") {
            Slider(
                value: $angle1,
                in: -90 ... 90,
                step: 5
            )
            Text("\(grid.angle1.shortDescription)")
                .contextualFont()
        }
    }
}
