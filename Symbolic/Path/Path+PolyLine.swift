import Foundation

fileprivate protocol Tessellatable {
    func tessellated(from: Point2, to: Point2, count: Int) -> PolyLine
}

extension PathEdge.Arc: Tessellatable {
    func tessellated(from: Point2, to: Point2, count: Int = 16) -> PolyLine {
        let params = toParams(from: from, to: to).centerParams
        let points = (0 ... count).map { i -> Point2 in params.position(paramT: CGFloat(i) / CGFloat(count)) }
        return PolyLine(points: points)
    }
}

extension PathEdge.Bezier: Tessellatable {
    func tessellated(from: Point2, to: Point2, count: Int = 16) -> PolyLine {
        let points = (0 ... count).map { i in position(from: from, to: to, paramT: CGFloat(i) / CGFloat(count)) }
        return PolyLine(points: points)
    }
}

extension PathEdge.Line: Tessellatable {
    func tessellated(from: Point2, to: Point2, count: Int = 16) -> PolyLine {
        let points = (0 ... count).map { i in position(from: from, to: to, paramT: CGFloat(i) / CGFloat(count)) }
        return PolyLine(points: points)
    }
}
