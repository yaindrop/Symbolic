//
//  PathModel.swift
//  Symbolic
//
//  Created by Yaindrop on 2024/4/11.
//

import Foundation

// MARK: SVGParser

class SVGParserDelegate: NSObject, XMLParserDelegate {
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        switch elementName {
        case "circle", "rect", "path":
            if let id = attributeDict["id"] {
                print("Found \(elementName) with id: \(id)")
            } else {
                print("Found \(elementName)")
            }
            print("\t\(attributeDict)")
            if let s = attributeDict["d"] {
                let parser = SVGPathParser(data: s)
                try! parser.parse()
                print(parser.paths)
            }
        default:
            print("Unknown name \(elementName)")
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        let trimmedString = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedString.isEmpty {
            print("Found characters: \(trimmedString)")
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        print("Ended element: \(elementName)")
    }

    func parserDidEndDocument(_ parser: XMLParser) {
        print("Finished parsing document.")
    }
}

struct BezierPathVertex {
    var location: CGPoint
    var controls: (CGPoint, CGPoint)?
}

struct BezierPath {
    var vertices: Array<BezierPathVertex>

    static func foo() {
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
        parser.parse()
    }
}
