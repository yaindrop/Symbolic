import Combine
import Foundation

// MARK: - SVGParserDelegate

class SVGParserDelegate: NSObject, XMLParserDelegate, CancellableHolder {
    var cancellables = Set<AnyCancellable>()

    func onPath(_ callback: @escaping (SVGPath) -> Void) {
        pathSubject
            .sink(receiveValue: callback)
            .store(in: self)
    }

    // MARK: handler

    func parser(_: XMLParser, didStartElement elementName: String, namespaceURI _: String?, qualifiedName _: String?, attributes attributeDict: [String: String] = [:]) {
        switch elementName {
        case "path":
            onPathElement(with: attributeDict)
        default:
            logInfo("Found element name \(elementName)")
        }
    }

    func parser(_: XMLParser, foundCharacters string: String) {
        let trimmedString = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedString.isEmpty {
            logInfo("Found characters: \(trimmedString)")
        }
    }

    func parser(_: XMLParser, didEndElement elementName: String, namespaceURI _: String?, qualifiedName _: String?) {
        logInfo("Ended element: \(elementName)")
    }

    func parserDidEndDocument(_: XMLParser) {
        logInfo("Finished parsing document.")
    }

    // MARK: private

    private let pathSubject = PassthroughSubject<SVGPath, Never>()
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
            logError("SVGPathParserError: \(error).")
        } catch {
            logError("Unexpected error: \(error).")
        }
    }
}
