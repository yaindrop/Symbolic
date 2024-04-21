import Combine
import Foundation

class SVGParserDelegate: NSObject, XMLParserDelegate {
    var pathSubject = PassthroughSubject<SVGPath, Never>()

    func onPath(_ callback: @escaping (SVGPath) -> Void) {
        pathSubject.sink { value in callback(value) }.store(in: &subscriptions)
    }

    // MARK: handler

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        switch elementName {
        case "path":
            onPathElement(with: attributeDict)
        default:
            print("Found element name \(elementName)")
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

    // MARK: private

    private var subscriptions = Set<AnyCancellable>()

    private func onPathElement(with attributes: [String: String]) {
        guard let definitions = attributes["d"] else { return }
        let parser = SVGPathParser(data: definitions)
        do {
            try parser.parse()
            for path in parser.paths {
                pathSubject.send(path)
            }
        } catch let error as SVGPathParserError {
            print("SVGPathParserError: \(error).")
        } catch {
            print("Unexpected error: \(error).")
        }
    }
}
