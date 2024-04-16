//
//  CG+Arithmetics.swift
//  Symbolic
//
//  Created by Yaindrop on 2024/4/10.
//

import CoreGraphics
import Foundation

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

// MARK: CGVector

extension CGFloat {
    var shortDescription: String { String(format: "%.3f", self) }
}

extension CGVector: AdditiveArithmetic {
    // MARK: AdditiveArithmetic

    public static func + (lhs: CGVector, rhs: CGVector) -> CGVector { CGVector(dx: lhs.dx + rhs.dx, dy: lhs.dy + rhs.dy) }

    public static func - (lhs: CGVector, rhs: CGVector) -> CGVector { CGVector(dx: lhs.dx - rhs.dx, dy: lhs.dy - rhs.dy) }

    public static func += (lhs: inout CGVector, rhs: CGVector) { lhs = lhs + rhs }

    public static func -= (lhs: inout CGVector, rhs: CGVector) { lhs = lhs - rhs }

    public static prefix func - (vector: CGVector) -> CGVector { CGVector(dx: -vector.dx, dy: -vector.dy) }

    // MARK: multiply by scalar

    public static func * (lhs: CGVector, rhs: CGFloat) -> CGVector { CGVector(dx: lhs.dx * rhs, dy: lhs.dy * rhs) }

    public static func * (lhs: CGFloat, rhs: CGVector) -> CGVector { rhs * lhs }

    public static func / (lhs: CGVector, rhs: CGFloat) -> CGVector { CGVector(dx: lhs.dx / rhs, dy: lhs.dy / rhs) }

    public static func *= (lhs: inout CGVector, rhs: CGFloat) { lhs = lhs * rhs }

    public static func /= (lhs: inout CGVector, rhs: CGFloat) { lhs = lhs / rhs }

    public func dotProduct(_ rhs: CGVector) -> CGFloat { dx * rhs.dx + dy * rhs.dy }

    public func crossProduct(_ rhs: CGVector) -> CGFloat { dx * rhs.dy - dy * rhs.dx }

    public func radian(_ v: CGVector) -> CGFloat {
        let dot = dotProduct(v)
        let mod = length() * v.length()
        var rad = acos(dot / mod)
        if crossProduct(v) < 0 {
            rad = -rad
        }
        return rad
    }

    // MARK: conversions

    init(from point: CGPoint) { self.init(dx: point.x, dy: point.y) }

    init(from size: CGSize) { self.init(dx: size.width, dy: size.height) }

    func length() -> CGFloat { hypot(dx, dy) }

    func applying(_ t: CGAffineTransform) -> CGVector {
        var translationCancelled = t
        translationCancelled.tx = 0
        translationCancelled.ty = 0
        return CGVector(from: CGPoint(from: self).applying(translationCancelled))
    }

    var shortDescription: String { String(format: "(%.3f, %.3f)", dx, dy) }
}

// MARK: CGPoint

extension CGPoint {
    // MARK: adding vector

    public static func + (lhs: CGPoint, rhs: CGVector) -> CGPoint { CGPoint(x: lhs.x + rhs.dx, y: lhs.y + rhs.dy) }

    public static func - (lhs: CGPoint, rhs: CGVector) -> CGPoint { CGPoint(x: lhs.x - rhs.dx, y: lhs.y - rhs.dy) }

    public static func += (lhs: inout CGPoint, rhs: CGVector) { lhs = lhs + rhs }

    public static func -= (lhs: inout CGPoint, rhs: CGVector) { lhs = lhs - rhs }

    // MARK: conversions

    init(from vector: CGVector) { self.init(x: vector.dx, y: vector.dy) }

    func deltaVector(to point: CGPoint) -> CGVector { CGVector(dx: point.x - x, dy: point.y - y) }

    func distance(to point: CGPoint) -> CGFloat { deltaVector(to: point).length() }

    var shortDescription: String { String(format: "(%.3f, %.3f)", x, y) }
}

// MARK: CGRect

extension CGRect {
    init(from size: CGSize) {
        self.init(x: 0, y: 0, width: size.width, height: size.height)
    }

    public init(center: CGPoint, size: CGSize) {
        self.init(origin: center - CGVector(from: size) / 2, size: size)
    }

    var center: CGPoint { CGPoint(x: midX, y: midY) }
}

// MARK: CGAffineTransform

extension CGAffineTransform {
    init(translation vector: CGVector) { self.init(translationX: vector.dx, y: vector.dy) }

    init(scale: CGFloat) { self.init(scaleX: scale, y: scale) }

    var translation: CGVector { CGVector(dx: tx, dy: ty) }

    public func apply<T>(_ mapper: (Self) -> T) -> T { mapper(self) }

    public func centered(at anchor: CGPoint, mapper: (CGAffineTransform) -> CGAffineTransform) -> CGAffineTransform {
        translatedBy(x: anchor.x, y: anchor.y)
            .apply(mapper)
            .translatedBy(x: -anchor.x, y: -anchor.y)
    }

    public func translatedBy(translation vector: CGVector) -> CGAffineTransform { translatedBy(x: vector.dx, y: vector.dy) }

    public func scaledBy(scale: CGFloat) -> CGAffineTransform { scaledBy(x: scale, y: scale) }
}
