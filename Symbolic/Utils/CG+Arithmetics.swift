//
//  CG+Arithmetics.swift
//  Symbolic
//
//  Created by Yaindrop on 2024/4/10.
//

import CoreGraphics
import Foundation

// MARK: CGVector

extension CGFloat {
    var shortDescription: String { String(format: "%.3f", self) }
}

extension CGVector: AdditiveArithmetic {
    var shortDescription: String { String(format: "(%.3f, %.3f)", dx, dy) }

    init(_ x: CGFloat, _ y: CGFloat) { self.init(dx: x, dy: y) }

    init(_ point: CGPoint) { self.init(point.x, point.y) }

    init(_ size: CGSize) { self.init(size.width, size.height) }

    // MARK: vector operator

    public static func + (lhs: CGVector, rhs: CGVector) -> CGVector { CGVector(lhs.dx + rhs.dx, lhs.dy + rhs.dy) }

    public static func - (lhs: CGVector, rhs: CGVector) -> CGVector { CGVector(lhs.dx - rhs.dx, lhs.dy - rhs.dy) }

    public static func += (lhs: inout CGVector, rhs: CGVector) { lhs = lhs + rhs }

    public static func -= (lhs: inout CGVector, rhs: CGVector) { lhs = lhs - rhs }

    public static prefix func - (vector: CGVector) -> CGVector { CGVector(-vector.dx, -vector.dy) }

    // MARK: scalar operator

    public static func * (lhs: CGVector, rhs: CGFloat) -> CGVector { CGVector(lhs.dx * rhs, lhs.dy * rhs) }

    public static func * (lhs: CGFloat, rhs: CGVector) -> CGVector { rhs * lhs }

    public static func / (lhs: CGVector, rhs: CGFloat) -> CGVector { CGVector(lhs.dx / rhs, lhs.dy / rhs) }

    public static func *= (lhs: inout CGVector, rhs: CGFloat) { lhs = lhs * rhs }

    public static func /= (lhs: inout CGVector, rhs: CGFloat) { lhs = lhs / rhs }

    // MARK: geometric operation

    func dotProduct(_ rhs: CGVector) -> CGFloat { dx * rhs.dx + dy * rhs.dy }

    func crossProduct(_ rhs: CGVector) -> CGFloat { dx * rhs.dy - dy * rhs.dx }

    func radian(_ v: CGVector) -> CGFloat {
        let dot = dotProduct(v)
        let mod = length() * v.length()
        var rad = acos(dot / mod)
        if crossProduct(v) < 0 {
            rad = -rad
        }
        return rad
    }

    // MARK: init

    func length() -> CGFloat { hypot(dx, dy) }

    func applying(_ t: CGAffineTransform) -> CGVector {
        var translationCancelled = t
        translationCancelled.tx = 0
        translationCancelled.ty = 0
        return CGVector(CGPoint(self).applying(translationCancelled))
    }
}

// MARK: CGPoint

extension CGPoint {
    var shortDescription: String { String(format: "(%.3f, %.3f)", x, y) }

    init(_ x: CGFloat, _ y: CGFloat) { self.init(x: x, y: y) }

    init(_ vector: CGVector) { self.init(vector.dx, vector.dy) }

    // MARK: operator

    public static func + (lhs: CGPoint, rhs: CGVector) -> CGPoint { CGPoint(CGVector(lhs) + rhs) }

    public static func - (lhs: CGPoint, rhs: CGVector) -> CGPoint { CGPoint(CGVector(lhs) - rhs) }

    public static func += (lhs: inout CGPoint, rhs: CGVector) { lhs = lhs + rhs }

    public static func -= (lhs: inout CGPoint, rhs: CGVector) { lhs = lhs - rhs }

    // MARK: geometric operation

    func deltaVector(to point: CGPoint) -> CGVector { CGVector(point) - CGVector(self) }

    func distance(to point: CGPoint) -> CGFloat { deltaVector(to: point).length() }
}

// MARK: CGSize

extension CGSize {
    init(_ width: CGFloat, _ height: CGFloat) { self.init(width: width, height: height) }
}

// MARK: CGRect

extension CGRect {
    var center: CGPoint { CGPoint(midX, midY) }

    init(_ size: CGSize) { self.init(x: 0, y: 0, width: size.width, height: size.height) }

    init(center: CGPoint, size: CGSize) { self.init(origin: center - CGVector(size) / 2, size: size) }
}

// MARK: CGAffineTransform

extension CGAffineTransform {
    var translation: CGVector { CGVector(tx, ty) }

    init(translation vector: CGVector) { self.init(translationX: vector.dx, y: vector.dy) }

    init(scale: CGFloat) { self.init(scaleX: scale, y: scale) }

    func apply<T>(_ mapper: (Self) -> T) -> T { mapper(self) }

    func centered(at anchor: CGPoint, mapper: (CGAffineTransform) -> CGAffineTransform) -> CGAffineTransform {
        translatedBy(CGVector(anchor))
            .apply(mapper)
            .translatedBy(-CGVector(anchor))
    }

    func translatedBy(_ vector: CGVector) -> CGAffineTransform { translatedBy(x: vector.dx, y: vector.dy) }

    func scaledBy(_ scale: CGFloat) -> CGAffineTransform { scaledBy(x: scale, y: scale) }
}
