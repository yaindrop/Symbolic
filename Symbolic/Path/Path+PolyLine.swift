import Foundation

extension PathEdge.Bezier {
    func tessellated(from: Point2, to: Point2, count: Int = 16) -> PolyLine {
        let points = (0 ... count).map { i in position(from: from, to: to, paramT: CGFloat(i + 1) / CGFloat(count)) }
        return PolyLine(points: points)
    }
}
