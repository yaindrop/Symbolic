import Foundation

fileprivate protocol Tessellatable {
    func tessellated(count: Int) -> PolyLine
}

extension PathSegment.Arc: Tessellatable {
    func tessellated(count: Int = 16) -> PolyLine {
        let params = arc.toParams(from: from, to: to).centerParams
        let points = (0 ... count).map { i -> Point2 in params.position(paramT: CGFloat(i) / CGFloat(count)) }
        return PolyLine(points: points)
    }
}

extension PathSegment.Bezier: Tessellatable {
    func tessellated(count: Int = 16) -> PolyLine {
        let points = (0 ... count).map { i in position(paramT: CGFloat(i) / CGFloat(count)) }
        return PolyLine(points: points)
    }
}

extension PathSegment.Line: Tessellatable {
    func tessellated(count: Int = 16) -> PolyLine {
        let points = (0 ... count).map { i in position(paramT: CGFloat(i) / CGFloat(count)) }
        return PolyLine(points: points)
    }
}
