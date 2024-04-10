//
//  CG+Arithmetics.swift
//  Symbolic
//
//  Created by Yaindrop on 2024/4/10.
//

import CoreGraphics
import Foundation

// MARK: CGVector

extension CGVector: AdditiveArithmetic {
    // MARK: AdditiveArithmetic

    public static func + (lhs: CGVector, rhs: CGVector) -> CGVector {
        return CGVector(dx: lhs.dx + rhs.dx, dy: lhs.dy + rhs.dy)
    }

    public static func - (lhs: CGVector, rhs: CGVector) -> CGVector {
        return CGVector(dx: lhs.dx - rhs.dx, dy: lhs.dy - rhs.dy)
    }

    public static func += (lhs: inout CGVector, rhs: CGVector) {
        lhs = lhs + rhs
    }

    public static func -= (lhs: inout CGVector, rhs: CGVector) {
        lhs = lhs - rhs
    }

    public static prefix func - (vector: CGVector) -> CGVector {
        return CGVector(dx: -vector.dx, dy: -vector.dy)
    }

    // MARK: multiply by scalar

    public static func * (lhs: CGVector, rhs: CGFloat) -> CGVector {
        return CGVector(dx: lhs.dx * rhs, dy: lhs.dy * rhs)
    }

    public static func * (lhs: CGFloat, rhs: CGVector) -> CGVector {
        return rhs * lhs
    }

    public static func / (lhs: CGVector, rhs: CGFloat) -> CGVector {
        return CGVector(dx: lhs.dx / rhs, dy: lhs.dy / rhs)
    }

    public static func *= (lhs: inout CGVector, rhs: CGFloat) {
        lhs = lhs * rhs
    }

    public static func /= (lhs: inout CGVector, rhs: CGFloat) {
        lhs = lhs / rhs
    }

    // MARK: conversions

    init(from point: CGPoint) {
        self.init(dx: point.x, dy: point.y)
    }

    init(from size: CGSize) {
        self.init(dx: size.width, dy: size.height)
    }

    func length() -> CGFloat {
        return hypot(dx, dy)
    }
}

// MARK: CGPoint

extension CGPoint {
    // MARK: adding vector

    public static func + (lhs: CGPoint, rhs: CGVector) -> CGPoint {
        return CGPoint(x: lhs.x + rhs.dx, y: lhs.y + rhs.dy)
    }

    public static func - (lhs: CGPoint, rhs: CGVector) -> CGPoint {
        return CGPoint(x: lhs.x - rhs.dx, y: lhs.y - rhs.dy)
    }

    public static func += (lhs: inout CGPoint, rhs: CGVector) {
        lhs = lhs + rhs
    }

    public static func -= (lhs: inout CGPoint, rhs: CGVector) {
        lhs = lhs - rhs
    }

    // MARK: conversions

    init(from vector: CGVector) {
        self.init(x: vector.dx, y: vector.dy)
    }

    func deltaVector(to point: CGPoint) -> CGVector {
        return CGVector(dx: point.x - x, dy: point.y - y)
    }

    func distance(to point: CGPoint) -> CGFloat {
        return deltaVector(to: point).length()
    }
}

// MARK: CGRect

extension CGRect {
    var center: CGPoint {
        return CGPoint(x: midX, y: midY)
    }
}

// MARK: CGAffineTransform

extension CGAffineTransform {
    init(translation vector: CGVector) {
        self.init(translationX: vector.dx, y: vector.dy)
    }

    public func scaledBy(xy scale: CGFloat) -> CGAffineTransform {
        return scaledBy(x: scale, y: scale)
    }
}
