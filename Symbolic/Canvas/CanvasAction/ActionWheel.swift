import SwiftUI

// MARK: - ActionWheel

struct ActionWheel<Icon: View>: View, TracedView {
    struct Configs {
        var count: Int
    }

    var configs: Configs
    var offset: Vector2
    @ViewBuilder var icon: (Int) -> Icon

    @ViewBuilder var body: some View { trace {
        content
    } }
}

// MARK: private

private extension ActionWheel {
    var offsetAngle: Angle {
        let radian = Vector2.unitX.radian(to: offset)
        return .radians(radian + (radian > 0 ? 0 : 2 * .pi))
    }

    var size: CGSize { .init(squared: 200) }

    var rotation: Angle {
        .degrees(3 * log(offset.length + 1))
    }

    var axis: (x: Scalar, y: Scalar, z: Scalar) {
        (x: offset.normalLeft.dx, y: offset.normalLeft.dy, z: 0)
    }

    var content: some View {
        ZStack {
            ForEach(0 ... configs.count - 1, id: \.self) { index in
                let startAngle = Angle.radians(2 * .pi * Scalar(index) / Scalar(configs.count)),
                    endAngle = Angle.radians(2 * .pi * Scalar(index + 1) / Scalar(configs.count)),
                    selected = (startAngle ... endAngle).contains(offsetAngle) && offset.length > size.width / 4
                let center = CGRect(size).center
                WheelArc(startAngle: startAngle, endAngle: endAngle, selected: selected)
                    .fill(Color.label.opacity(selected ? 0.2 : 0.1))
                icon(index)
                    .position(center + Vector2(angle: startAngle, length: size.width / 3))
            }
            SUPath {
                let center = CGRect(size).center
                $0.move(to: center)
                $0.addLine(to: center + offset)
            }
            .stroke(.red)
        }
        .frame(size: size)
        .animation(.faster, value: offset)
        .rotation3DEffect(rotation, axis: axis, anchor: .center)
        .transition(.opacity)
        .allowsHitTesting(false)
    }
}

// MARK: - WheelArc

struct WheelArc: Shape {
    let startAngle: Angle, endAngle: Angle, selected: Bool

    private var innerRatio: Scalar, outerRatio: Scalar

    var animatableData: AnimatablePair<Scalar, Scalar> {
        get { .init(innerRatio, outerRatio) }
        set {
            innerRatio = newValue.first
            outerRatio = newValue.second
        }
    }

    init(startAngle: Angle, endAngle: Angle, selected: Bool) {
        self.startAngle = startAngle
        self.endAngle = endAngle
        self.selected = selected
        innerRatio = selected ? 0.45 : 0.5
        outerRatio = selected ? 1 : 0.95
    }

    var borderGapRatio: Scalar { 0.05 }

    func path(in rect: CGRect) -> SUPath {
        let center = rect.center,
            radius = rect.width / 2,
            innerRadius = radius * innerRatio,
            outerRadius = radius * outerRatio,
            startAngle = startAngle,
            endAngle = endAngle,
            arcPath = SUPath {
                $0.addArc(center: center, radius: innerRadius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
                $0.addArc(center: center, radius: outerRadius, startAngle: endAngle, endAngle: startAngle, clockwise: true)
                $0.closeSubpath()
            },
            borderPath = SUPath {
                guard let startLine = Line(point: center, angle: startAngle).segment(in: rect),
                      let endLine = Line(point: center, angle: endAngle).segment(in: rect) else { return }
                $0.move(to: startLine.start)
                $0.addLine(to: startLine.end)
                $0.move(to: endLine.start)
                $0.addLine(to: endLine.end)
            }
            .strokedPath(.init(lineWidth: radius * borderGapRatio))
        return arcPath.subtracting(borderPath)
    }
}
