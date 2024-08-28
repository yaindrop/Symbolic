import Foundation

// MARK: - Symbol

struct Symbol: Identifiable, Equatable, Codable, TriviallyCloneable {
    let id: UUID
    var origin: Point2
    var size: CGSize
    var grids: [Grid]
}

extension Symbol {
    var boundingRect: CGRect {
        .init(origin: origin, size: size)
    }

    var symbolToWorld: CGAffineTransform {
        .init(translation: .init(origin))
    }

    var worldToSymbol: CGAffineTransform {
        symbolToWorld.inverted()
    }
}

extension Symbol: CustomStringConvertible {
    var description: String {
        "Symbol(id: \(id.shortDescription), origin: \(origin), size: \(size))"
    }
}

extension Symbol {
    mutating func update(_ event: SymbolEvent.SetBounds) {
        origin = event.origin
        size = event.size
    }

    mutating func update(_ event: SymbolEvent.SetGrid) {
        let index = event.index,
            grid = event.grid
        if index == grids.count, index < 3, let grid {
            grids.append(grid)
        } else if grids.indices.contains(index) {
            if let grid {
                grids[index] = grid
            } else {
                grids.remove(at: index)
            }
        }
    }

    mutating func update(_ event: SymbolEvent.Move) {
        origin += event.offset
    }
}
