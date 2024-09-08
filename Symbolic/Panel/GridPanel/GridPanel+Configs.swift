import SwiftUI

// MARK: - global actions

private extension GlobalStores {
    func updateGrid(grid: Grid?, pending: Bool = false) {
        guard let symbolId = activeSymbol.editingSymbolId,
              grid != activeSymbol.grid else { return }
        let index = activeSymbol.gridIndex
        documentUpdater.update(symbol: .setGrid(.init(symbolId: symbolId, index: index, grid: grid)), pending: pending)
    }

    func addGrid() {
        guard let symbol = activeSymbol.editingSymbol,
              symbol.grids.count < 3 else { return }
        let grid = Grid(kind: .cartesian(.init(interval: 8)))
        documentUpdater.update(symbol: .setGrid(.init(symbolId: symbol.id, index: symbol.grids.count, grid: grid)))
    }

    func deleteGrid() {
        updateGrid(grid: nil)
    }

    func updateGrid(tintColor: CGColor, pending: Bool = false) {
        guard var grid = activeSymbol.grid else { return }
        grid.tintColor = tintColor
        updateGrid(grid: grid, pending: pending)
    }

    func updateGrid(gridCase: Grid.Case) {
        guard var grid = activeSymbol.grid,
              gridCase != grid.case else { return }
        switch gridCase {
        case .cartesian: grid.kind = .cartesian(.init(interval: 8))
        case .isometric: grid.kind = .isometric(.init(interval: 8, angle0: .degrees(30), angle1: .degrees(-30)))
        case .radial: break
        }
        updateGrid(grid: grid)
    }

    func updateGrid(cartesian: Grid.Cartesian, pending: Bool = false) {
        guard var grid = activeSymbol.grid else { return }
        grid.kind = .cartesian(cartesian)
        updateGrid(grid: grid, pending: pending)
    }

    func updateGrid(isometric: Grid.Isometric, pending: Bool = false) {
        guard var grid = activeSymbol.grid else { return }
        grid.kind = .isometric(isometric)
        updateGrid(grid: grid, pending: pending)
    }
}

// MARK: - Configs

extension GridPanel {
    struct Configs: View, TracedView, SelectorHolder {
        class Selector: SelectorBase {
            @Selected({ global.activeSymbol.grids }, .animation(.fast)) var gridStack
            @Selected({ global.activeSymbol.grid }, .animation(.fast)) var grid
        }

        @SelectorWrapper var selector

        @State private var tintColor = UIColor.red.cgColor

        @State private var gridCase: Grid.Case = .cartesian

        var body: some View { trace {
            setupSelector {
                if let grid = selector.grid {
                    content
                        .onChange(of: tintColor) { global.updateGrid(tintColor: tintColor) }
                        .onChange(of: gridCase) { global.updateGrid(gridCase: gridCase) }
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
            case .cartesian: Cartesian(grid: grid)
            case .isometric: Isometric(grid: grid)
            case .radial: EmptyView()
            }
        }
    }

    var editRow: some View {
        ContextualRow {
            Button(role: .destructive) { global.deleteGrid() } label: {
                Image(systemName: "trash")
            }
            .buttonBorderShape(.capsule)
            .buttonStyle(.bordered)
            .disabled(selector.gridStack.count == 1)
            Spacer()
            Button { global.addGrid() } label: {
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
        let grid: Grid

        @EnvironmentObject private var viewModel: GridPanel.ViewModel

        @State private var interval: Scalar

        init(grid: Grid) {
            self.grid = grid
            interval = grid.cartesian?.interval ?? 0
        }

        var body: some View { trace {
            content
                .onChange(of: updated) { global.updateGrid(cartesian: updated, pending: true) }
        } }
    }
}

// MARK: private

private extension GridPanel.Configs.Cartesian {
    @ViewBuilder var content: some View {
        intervalRow
    }

    var updated: Grid.Cartesian { .init(interval: interval) }

    var intervalRow: some View {
        ContextualRow(label: "Interval") {
            Slider(
                value: $interval,
                in: 2 ... 64,
                step: 1,
                onEditingChanged: { editing in
                    viewModel.intervalCommit.send()
                    if !editing {
                        global.updateGrid(cartesian: updated)
                    }
                }
            )
            let interval = grid.isometric?.interval ?? 0
            Text("\(Int(interval))")
                .contextualFont()
        }
    }
}

// MARK: - IsometricConfigs

private extension GridPanel.Configs {
    struct Isometric: View, TracedView {
        let grid: Grid

        @EnvironmentObject private var viewModel: GridPanel.ViewModel

        @State private var interval: Scalar
        @State private var angle0: Scalar
        @State private var angle1: Scalar

        init(grid: Grid) {
            self.grid = grid
            interval = grid.isometric?.interval ?? 0
            angle0 = grid.isometric?.angle0.degrees ?? 0
            angle1 = grid.isometric?.angle1.degrees ?? 0
        }

        var body: some View { trace {
            content
                .onChange(of: updated) { global.updateGrid(isometric: updated, pending: true) }
        } }
    }
}

// MARK: private

private extension GridPanel.Configs.Isometric {
    @ViewBuilder var content: some View {
        intervalRow
        ContextualDivider()
        angle0Row
        ContextualDivider()
        angle1Row
    }

    var updated: Grid.Isometric { .init(interval: interval, angle0: .degrees(angle0), angle1: .degrees(angle1)) }

    var intervalRow: some View {
        ContextualRow(label: "Interval") {
            Slider(
                value: $interval,
                in: 2 ... 64,
                step: 1,
                onEditingChanged: { editing in
                    viewModel.intervalCommit.send()
                    if !editing {
                        global.updateGrid(isometric: updated)
                    }
                }
            )
            let interval = grid.isometric?.interval ?? 0
            Text("\(Int(interval))")
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
            let angle0 = grid.isometric?.angle0 ?? .zero
            Text("\(angle0.shortDescription)")
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
            let angle1 = grid.isometric?.angle1 ?? .zero
            Text("\(angle1.shortDescription)")
                .contextualFont()
        }
    }
}
