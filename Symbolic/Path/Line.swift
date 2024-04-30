import Foundation

enum Line {
    protocol Form {
        func projected(from point: CGPoint) -> CGPoint
    }

    struct SlopeIntercept: Form {
        let m: CGFloat, b: CGFloat

        func y(x: CGFloat) -> CGFloat { m * x + b }

        func projected(from point: CGPoint) -> CGPoint {
            let x = (m * (point.y - b) + point.x) / (m * m + 1)
            return CGPoint(x, y(x: x))
        }
    }

    struct Vertical: Form {
        let x: CGFloat

        func projected(from point: CGPoint) -> CGPoint { CGPoint(x, point.y) }
    }

    case slopeIntercept(SlopeIntercept)
    case vertical(Vertical)
}

extension Line: Line.Form {
    var form: Form {
        switch self {
        case let .slopeIntercept(si): si
        case let .vertical(v): v
        }
    }

    func projected(from point: CGPoint) -> CGPoint { form.projected(from: point) }
}

enum LineSegment {
    protocol Form {
        var start: CGPoint { get }
        var end: CGPoint { get }
        var line: Line { get }
        func closest(to point: CGPoint) -> CGPoint
    }

    struct SlopeIntercept: Form {
        let lineForm: Line.SlopeIntercept
        let x0: CGFloat, x1: CGFloat

        var start: CGPoint { CGPoint(x0, lineForm.y(x: x0)) }
        var end: CGPoint { CGPoint(x1, lineForm.y(x: x1)) }

        var line: Line { .slopeIntercept(lineForm) }

        func closest(to point: CGPoint) -> CGPoint {
            let p = line.projected(from: point)
            return p.x < x0 ? start : p.x > x1 ? end : p
        }
    }

    struct Vertical: Form {
        let lineForm: Line.Vertical
        let y0: CGFloat, y1: CGFloat

        var start: CGPoint { CGPoint(lineForm.x, y0) }
        var end: CGPoint { CGPoint(lineForm.x, y1) }

        var line: Line { .vertical(lineForm) }

        func closest(to point: CGPoint) -> CGPoint {
            let p = line.projected(from: point)
            return p.y < y0 ? start : p.y > y1 ? end : p
        }
    }

    case slopeIntercept(SlopeIntercept)
    case vertical(Vertical)
}

extension LineSegment: LineSegment.Form {
    var form: Form {
        switch self {
        case let .slopeIntercept(si): si
        case let .vertical(v): v
        }
    }

    var start: CGPoint { form.start }
    var end: CGPoint { form.end }

    var line: Line { form.line }

    func closest(to point: CGPoint) -> CGPoint { form.closest(to: point) }
}
