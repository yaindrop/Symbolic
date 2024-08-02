import Foundation

// MARK: - BezierCurve

struct BezierCurve {
    var points: [Point2]

    init(points: [Point2]) {
        self.points = points
    }

    init(segment: PathSegment) {
        points = [segment.from, segment.fromOut, segment.toIn, segment.to]
    }
}

extension BezierCurve: Parametrizable {
    func position(paramT t: Scalar) -> Point2 {
        let degree = points.count - 1
        // Copy array
        var tmp = points
        // Triangle computation
        for i in 1 ... degree {
            for j in 0 ... degree - i {
                tmp[j] = Point2((Vector2(tmp[j]) * (1 - t)) + (Vector2(tmp[j + 1]) * t))
            }
        }
        return tmp[0]
    }
}

// MARK: - Polyline

extension Polyline {
    func fit(error: Scalar) -> [PathNode] {
        let length = points.count
        var nodes: [PathNode] = []
        if length > 0 {
            // To support reducing paths with multiple points in the same place
            // to one segment:
            nodes = [.init(position: points[0])]
            if length > 1 {
                let tan1 = points[1] - points[0] // Left Tangent
                let tan2 = points[length - 2] - points[length - 1] // Right Tangent
                fitCubic(nodes: &nodes, error: error, first: 0, last: length - 1, tan1: tan1, tan2: tan2)
            }
        }
        return nodes
    }
}

private extension Polyline {
    // Fit a Bezier curve to a (sub)set of digitized points
    func fitCubic(nodes: inout [PathNode], error: Scalar, first: Int, last: Int, tan1: Vector2, tan2: Vector2) {
        //  Use heuristic if region only has two points in it
        if last - first == 1 {
            let pt1 = points[first],
                pt2 = points[last],
                dist = pt1.distance(to: pt2) / 3
            let segment = PathSegment(from: pt1, to: pt2, fromCubicOut: tan1.with(length: dist), toCubicIn: tan2.with(length: dist))
            addSegment(nodes: &nodes, segment: segment)
            return
        }

        // Parameterize points, and attempt to fit curve
        var uPrime = chordLengthParameterize(first: first, last: last),
            maxError = max(error, error * error),
            split: Int?,
            parametersInOrder = true

        // Try 4 iterations
        for _ in 0 ... 4 {
            let segment = generateBezier(first: first, last: last, uPrime: uPrime, tan1: tan1, tan2: tan2)
            //  Find max deviation of points to fitted curve
            let max = findMaxError(first: first, last: last, segment: segment, u: uPrime)
            if max.error < error, parametersInOrder {
                addSegment(nodes: &nodes, segment: segment)
                return
            }
            split = max.index
            // If error not too large, try reparameterization and iteration
            if max.error >= maxError {
                break
            }
            parametersInOrder = reparameterize(first: first, last: last, u: &uPrime, segment: segment)
            maxError = max.error
        }

        guard let split else { fatalError() }
        // Fitting failed -- split at max error point and fit recursively
        let tanCenter = points[split - 1] - points[split + 1]
        fitCubic(nodes: &nodes, error: error, first: first, last: split, tan1: tan1, tan2: tanCenter)
        fitCubic(nodes: &nodes, error: error, first: split, last: last, tan1: -tanCenter, tan2: tan2)
    }

    func addSegment(nodes: inout [PathNode], segment: PathSegment) {
        if nodes.isEmpty {
            nodes.append(.init(position: segment.from, cubicOut: segment.fromCubicOut))
        } else {
            nodes[nodes.count - 1].cubicOut = segment.fromCubicOut
        }
        nodes.append(.init(position: segment.to, cubicIn: segment.toCubicIn))
    }

    // Use least-squares method to find Bezier control points for region.
    func generateBezier(first: Int, last: Int, uPrime: [Scalar], tan1: Vector2, tan2: Vector2) -> PathSegment {
        let epsilon = CGFLOAT_EPSILON,
            pt1 = points[first],
            pt2 = points[last]
        // Create the C and X matrices
        var C = Matrix2.zero,
            X = Vector2.zero

        for i in 0 ..< last - first + 1 {
            let u = uPrime[i],
                t = 1 - u,
                b = 3 * u * t,
                b0 = t * t * t,
                b1 = b * t,
                b2 = b * u,
                b3 = u * u * u,
                a1 = tan1.with(length: b1),
                a2 = tan2.with(length: b2),
                tmp = Vector2(points[first + i]) - Vector2(pt1) * (b0 + b1) - Vector2(pt2) * (b2 + b3)
            C[0][0] += a1.dotProduct(a1)
            C[0][1] += a1.dotProduct(a2)
            // C[1][0] += a1.dot(a2);
            C[1][0] = C[0][1]
            C[1][1] += a2.dotProduct(a2)
            X[0] += a1.dotProduct(tmp)
            X[1] += a2.dotProduct(tmp)
        }

        // Compute the determinants of C and X
        let detC0C1 = C[0][0] * C[1][1] - C[1][0] * C[0][1]
        var alpha1: Scalar,
            alpha2: Scalar
        if abs(detC0C1) > epsilon {
            // Kramer's rule
            let detC0X = C[0][0] * X[1] - C[1][0] * X[0],
                detXC1 = X[0] * C[1][1] - X[1] * C[0][1]
            // Derive alpha values
            alpha1 = detXC1 / detC0C1
            alpha2 = detC0X / detC0C1
        } else {
            // Matrix is under-determined, try assuming alpha1 == alpha2
            let c0 = C[0][0] + C[0][1],
                c1 = C[1][0] + C[1][1]
            alpha1 = abs(c0) > epsilon ? X[0] / c0
                : abs(c1) > epsilon ? X[1] / c1
                : 0
            alpha2 = alpha1
        }

        // If alpha negative, use the Wu/Barsky heuristic (see text)
        // (if alpha is 0, you get coincident control points that lead to
        // divide by zero in any subsequent NewtonRaphsonRootFind() call.
        let segLength = pt2.distance(to: pt1),
            eps = epsilon * segLength
        var handle1: Vector2?,
            handle2: Vector2?
        if alpha1 < eps || alpha2 < eps {
            // fall back on standard (probably inaccurate) formula,
            // and subdivide further if needed.
            alpha1 = segLength / 3
            alpha2 = alpha1
        } else {
            // Check if the found control points are in the right order when
            // projected onto the line through pt1 and pt2.
            let line = pt2 - pt1
            // Control points 1 and 2 are positioned an alpha distance out
            // on the tangent vectors, left and right, respectively
            handle1 = tan1.with(length: alpha1)
            handle2 = tan2.with(length: alpha2)
            if handle1!.dotProduct(line) - handle2!.dotProduct(line) > segLength * segLength {
                // Fall back to the Wu/Barsky heuristic above.
                alpha1 = segLength / 3
                alpha2 = alpha1
                handle1 = nil // Force recalculation
                handle2 = nil
            }
        }

        // First and last control points of the Bezier curve are
        // positioned exactly at the first and last data points
        return .init(from: pt1, to: pt2, fromCubicOut: handle1 ?? tan1.with(length: alpha1), toCubicIn: handle2 ?? tan2.with(length: alpha2))
    }

    // Given set of points and their parameterization, try to find
    // a better parameterization.
    func reparameterize(first: Int, last: Int, u: inout [Scalar], segment: PathSegment) -> Bool {
        for i in first ... last {
            u[i - first] = findRoot(segment: segment, point: points[i], u: u[i - first])
        }
        // Detect if the new parameterization has reordered the points.
        // In that case, we would fit the points of the path in the wrong order.
        for i in 1 ..< u.count {
            if u[i] <= u[i - 1] {
                return false
            }
        }
        return true
    }

    // Use Newton-Raphson iteration to find better root.
    func findRoot(segment: PathSegment, point: Point2, u: Scalar) -> Scalar {
        let curve = BezierCurve(segment: segment)
        var curve1 = BezierCurve(points: []),
            curve2 = BezierCurve(points: [])
        // Generate control vertices for Q'
        for i in 0 ... 2 {
            curve1.points[i] = curve.points[i + 1] - Vector2(curve.points[i]) * 3
        }
        // Generate control vertices for Q''
        for i in 0 ... 1 {
            curve2.points[i] = curve1.points[i + 1] - Vector2(curve1.points[i]) * 2
        }
        // Compute Q(u), Q'(u) and Q''(u)
        let pt = Vector2(curve.position(paramT: u)),
            pt1 = Vector2(curve1.position(paramT: u)),
            pt2 = Vector2(curve2.position(paramT: u)),
            diff = pt - Vector2(point),
            df = pt1.dotProduct(pt1) + diff.dotProduct(pt2)
        // u = u - f(u) / f'(u)
        return df.nearlyEqual(0, epsilon: CGFLOAT_EPSILON) ? u : u - diff.dotProduct(pt1) / df
    }

    // Assign parameter values to digitized points
    // using relative distances between points.
    func chordLengthParameterize(first: Int, last: Int) -> [Scalar] {
        var u: [Scalar] = Array(repeating: 0, count: last - first + 1)
        for i in first + 1 ... last {
            u[i - first] = u[i - first - 1]
                + points[i].distance(to: points[i - 1])
        }
        let m = last - first
        for i in 1 ... m {
            u[i] /= u[m]
        }
        return u
    }

    // Find the maximum squared distance of digitized points to fitted curve.
    func findMaxError(first: Int, last: Int, segment: PathSegment, u: [Scalar]) -> (error: Scalar, index: Int) {
        var index = Int(floor(Double(last - first + 1) / 2)),
            maxDist: Scalar = 0
        for i in first + 1 ..< last {
            let P = BezierCurve(segment: segment).position(paramT: u[i - first]),
                v = P - Vector2(points[i]),
                dist = v.x * v.x + v.y * v.y // squared
            if dist >= maxDist {
                maxDist = dist
                index = i
            }
        }
        return (maxDist, index)
    }
}
