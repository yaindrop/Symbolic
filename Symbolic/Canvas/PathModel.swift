//
//  PathModel.swift
//  Symbolic
//
//  Created by Yaindrop on 2024/4/11.
//

import Foundation

class SVGParser: NSObject, XMLParserDelegate {
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        switch elementName {
        case "circle", "rect", "path":
            if let id = attributeDict["id"] {
                print("Found \(elementName) with id: \(id)")
            } else {
                print("Found \(elementName)")
            }
            print("\t\(attributeDict)")
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
        <?xml version="1.0"?>
        <svg viewBox="0 0 18 12" xmlns="http://www.w3.org/2000/svg">
          <!--
          Upper left path:
          Effect of the "miter" value
          -->
          <path d="M1,5 a2,2 0,0,0 2,-3 a3,3 0 0 1 2,3.5" stroke="black" fill="none" stroke-linejoin="miter" />

          <!--
          Center path:
          Effect of the "round" value
          -->
          <path d="M7,5 a2,2 0,0,0 2,-3 a3,3 0 0 1 2,3.5" stroke="black" fill="none" stroke-linejoin="round" />

          <!--
          Upper right path:
          Effect of the "bevel" value
          -->
          <path d="M13,5 a2,2 0,0,0 2,-3 a3,3 0 0 1 2,3.5" stroke="black" fill="none" stroke-linejoin="bevel" />

          <!--
          Bottom left path:
          Effect of the "miter-clip" value
          with fallback to "miter" if not supported.
          -->
          <path d="M3,11 a2,2 0,0,0 2,-3 a3,3 0 0 1 2,3.5" stroke="black" fill="none" stroke-linejoin="miter-clip" />

          <!--
          Bottom right path:
          Effect of the "arcs" value
          with fallback to "miter" if not supported.
          -->
          <path d="M9,11 a2,2 0,0,0 2,-3 a3,3 0 0 1 2,3.5" stroke="black" fill="none" stroke-linejoin="arcs" />
        </svg>
        """.data(using: .utf8)!
        let parser = XMLParser(data: data)
        let svgParser = SVGParser()
        parser.delegate = svgParser
        parser.parse()
    }
}
