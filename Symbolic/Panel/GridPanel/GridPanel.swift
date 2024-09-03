import Combine
import SwiftUI

// MARK: - GridPanel

struct GridPanel: View, TracedView, SelectorHolder {
    class Selector: SelectorBase {
        @Selected(configs: .init(animation: .fast), { global.activeSymbol.grids }) var grids
        @Selected(configs: .init(animation: .fast), { global.activeSymbol.grid }) var grid
        @Selected(configs: .init(animation: .fast), { global.activeSymbol.gridIndex }) var gridIndex
    }

    @SelectorWrapper var selector

    @State private var index = 0

    var body: some View { trace {
        setupSelector {
            content
                .onChange(of: index) {
                    guard index != selector.gridIndex else { return }
                    global.activeSymbol.setGridIndex(index)
                }
                .bind(selector.gridIndex, to: $index)
                .environmentObject(ViewModel())
        }
    } }
}

extension GridPanel {
    class ViewModel: ObservableObject {
        @Passthrough<Void> var intervalCommit
    }
}

// MARK: private

extension GridPanel {
    @ViewBuilder private var content: some View {
        tabs
        preview
        configs
    }

    @ViewBuilder private var tabs: some View {
        let grids = selector.grids
        if grids.count > 1 {
            HStack {
                Picker("", selection: $index) {
                    Text("Primary").tag(0)
                    Text("Secondary").tag(1)
                    if grids.count > 2 {
                        Text("Tertiary").tag(2)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    @ViewBuilder private var preview: some View {
        if let grid = selector.grid {
            PanelSection(name: "Preview") {
                Preview(grid: grid)
            }
        }
    }

    @ViewBuilder private var configs: some View {
        PanelSection(name: "Configs") {
            Configs()
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
                .onReceive(viewModel.$intervalCommit) { _viewport.delayEnd() }
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
            ZStack {
                switch grid.kind {
                case let .cartesian(grid):
                    AnimatableReader(grid) {
                        GridLines(grid: .init(kind: .cartesian($0)), viewport: viewport)
                        GridLabels(grid: .init(kind: .cartesian($0)), viewport: viewport, hasSafeArea: false)
                    }
                case let .isometric(grid):
                    AnimatableReader(grid) {
                        GridLines(grid: .init(kind: .isometric($0)), viewport: viewport)
                        GridLabels(grid: .init(kind: .isometric($0)), viewport: viewport, hasSafeArea: false)
                    }
                default: EmptyView()
                }
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
