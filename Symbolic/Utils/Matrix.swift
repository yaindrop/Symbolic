//
//  Matrix.swift
//  Symbolic
//
//  Created by Yaindrop on 2024/4/21.
//

import Foundation

// MARK: Matrix2

struct Matrix2 {
    var a: CGFloat
    var b: CGFloat
    var c: CGFloat
    var d: CGFloat

    var rows: (CGVector, CGVector) { (CGVector(dx: a, dy: b), CGVector(dx: c, dy: d)) }
    var cols: (CGVector, CGVector) { (CGVector(dx: a, dy: c), CGVector(dx: b, dy: d)) }

    init(a: CGFloat, b: CGFloat, c: CGFloat, d: CGFloat) {
        self.a = a
        self.b = b
        self.c = c
        self.d = d
    }

    init(row0: CGVector, row1: CGVector) { self.init(a: row0.dx, b: row0.dy, c: row1.dx, d: row1.dy) }

    init(col0: CGVector, col1: CGVector) { self.init(a: col0.dx, b: col1.dx, c: col0.dy, d: col1.dy) }

    public static func * (lhs: Matrix2, rhs: CGVector) -> CGVector {
        let rows = lhs.rows
        return CGVector(dx: rows.0.dotProduct(rhs), dy: rows.1.dotProduct(rhs))
    }

    public static func * (lhs: Matrix2, rhs: Matrix2) -> Matrix2 {
        let cols = rhs.cols
        return Matrix2(col0: lhs * cols.0, col1: lhs * cols.1)
    }
}
