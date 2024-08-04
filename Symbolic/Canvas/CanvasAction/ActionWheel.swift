import SwiftUI

// MARK: - ActionWheel

struct ActionWheel: View, TracedView {
    struct Option {
        var name: String
        var imageName: String
        var onSelect: () -> Void
    }

    var offset: Vector2
    var options: [Option]
    @Binding var hovering: Option?

    @ViewBuilder var body: some View { trace {
        content
    } }
}

// MARK: private

private extension ActionWheel {
    var content: some View {
        ZStack {
            ForEach(options.indices, id: \.self) { index in
                let selected = selected(index),
                    startAngle = startAngle(index),
                    endAngle = endAngle(index),
                    midAngle = midAngle(index),
                    innerRatio = innerRatio - (selected ? deltaRatio : 0),
                    outerRatio = outerRatio + (selected ? deltaRatio : 0)
                WheelArc(startAngle: startAngle, endAngle: endAngle, innerRatio: innerRatio, outerRatio: outerRatio)
                    .fill(selected ? Color.blue.opacity(0.2) : Color.label.opacity(0.1))
                Image(systemName: options[index].imageName)
                    .font(selected ? .body.bold() : .body)
                    .foregroundColor(selected ? .blue : .label)
                    .position(center + Vector2(angle: midAngle, length: radius * midRatio))
            }
            SUPath {
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
        .onChange(of: selectedIndex) { _, index in
            hovering = index.map { options[$0] }
        }
    }

    var size: CGSize { .init(squared: 200) }

    var center: Point2 { CGRect(size).center }

    var rotation: Angle {
        .degrees(3 * log(offset.length + 1))
    }

    var axis: (Scalar, Scalar, Scalar) {
        let normal = offset.normalLeft
        return (normal.dx, normal.dy, 0)
    }

    // MARK: radius ratio

    var radius: Scalar { size.width / 2 }

    var innerRatio: Scalar { 0.5 }

    var outerRatio: Scalar { 1 }

    var midRatio: Scalar { (innerRatio + outerRatio) / 2 }

    var deltaRatio: Scalar { 0.05 }

    // MARK: angle

    var offsetAngle: Angle {
        let radian = Vector2.unitX.radian(to: offset)
        return .radians(radian + (radian > 0 ? 0 : 2 * .pi))
    }

    func startAngle(_ index: Int) -> Angle {
        .radians(2 * .pi * Scalar(index) / Scalar(options.count))
    }

    func endAngle(_ index: Int) -> Angle {
        .radians(2 * .pi * Scalar(index + 1) / Scalar(options.count))
    }

    func midAngle(_ index: Int) -> Angle {
        .radians(2 * .pi * (Scalar(index) + 0.5) / Scalar(options.count))
    }

    // MARK: selected

    func selected(_ index: Int) -> Bool {
        (startAngle(index) ... endAngle(index)).contains(offsetAngle) && offset.length > radius * midRatio
    }

    var selectedIndex: Int? {
        options.indices.first { selected($0) }
    }
}

// MARK: - WheelArc

struct WheelArc: Shape {
    var startAngle: Angle
    var endAngle: Angle
    var innerRatio: Scalar
    var outerRatio: Scalar

    var animatableData: AnimatablePair<Scalar, Scalar> {
        get { .init(innerRatio, outerRatio) }
        set { (innerRatio, outerRatio) = newValue.tuple }
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
                let rect = rect.outset(by: rect.width)
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
