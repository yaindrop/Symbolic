//
//  Path.swift
//  Symbolic
//
//  Created by Yaindrop on 2024/4/11.
//

import Foundation

struct PathArc {
    var radius: CGSize
    var rotation: CGFloat = 0
    var largeArc: Bool = false
    var sweep: Bool = false
}

struct PathBezier {
    var control0: CGPoint
    var control1: CGPoint
}

enum PathAction {
    case Line
    case Arc(PathArc)
    case Bezier(PathBezier)
}

struct PathVertex: Identifiable {
    let id = UUID()
    var position: CGPoint
}

struct Path: Identifiable {
    let id = UUID()
    var pairs: Array<(PathVertex, PathAction)> = []
}

func foo() {
    let data = """
    <svg width="300" height="200" xmlns="http://www.w3.org/2000/svg">
      <!-- Define the complex path with different commands -->
      <path d="M 0 0 L 50 50 L 100 0 Z
               M 50 100
               C 60 110, 90 140, 100 150
               S 180 120, 150 100
               Q 160 180, 150 150
               T 200 150
               A 50 50 0 0 1 250 100
               Z" fill="none" stroke="black" stroke-width="2" />
    </svg>
    """.data(using: .utf8)!
    let parser = XMLParser(data: data)
    let delegate = SVGParserDelegate()
    parser.delegate = delegate
    delegate.onPath { svgPath in
        print(Path(from: svgPath))
    }
    parser.parse()
}
