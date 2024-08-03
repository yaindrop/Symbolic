import SwiftUI

struct ActionWheel: View {
    var vector: Vector2

    var count: Int { 8 }

    var body: some View {
        Rectangle()
            .fill(.clear)
            .frame(size: .init(squared: 1))
            .overlay {
                ForEach(0 ... count - 1, id: \.self) {
                    arcPath(index: $0)
                }
                SUPath {
                    $0.move(to: .zero)
                    $0.addLine(to: .init(vector))
                }
                .stroke(.red)
            }
            .allowsHitTesting(false)
            .animation(.default, value: vector)
    }

    @ViewBuilder func arcPath(index i: Int) -> some View {
        let length = Scalar.pi * 2.0 / Scalar(count),
            start = Scalar(i) * length,
            end = (Scalar(i) + 1) * length,
            radian = Vector2.unitX.radian(to: vector),
            angle = radian < 0 ? 2 * .pi + radian : radian,
            selected = angle > .init(start) && angle < .init(end)
        SUPath {
            $0.addArc(center: .zero, radius: selected ? 30 : 40, startAngle: .radians(.init(start)), endAngle: .radians(.init(end)), clockwise: false)
            $0.addArc(center: .zero, radius: selected ? 90 : 80, startAngle: .radians(.init(end)), endAngle: .radians(.init(start)), clockwise: true)
            $0.closeSubpath()
        }
        .subtracting(.init {
            guard let startLine = Line(b: 0, angle: .radians(.init(start))).segment(in: .init(center: .zero, size: .init(squared: 200))) else { return }
            guard let endLine = Line(b: 0, angle: .radians(.init(end))).segment(in: .init(center: .zero, size: .init(squared: 200))) else { return }
            $0.move(to: startLine.start)
            $0.addLine(to: startLine.end)
            $0.move(to: endLine.start)
            $0.addLine(to: endLine.end)
            $0 = $0.strokedPath(.init(lineWidth: 4))
        })
        .fill(Color.label.opacity(selected ? 0.2 : 0.1))
    }
}
