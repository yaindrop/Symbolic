import Foundation

struct PathTessellation {
    let vertices: [Point2]

    let length: CGFloat

    var count: Int { vertices.count }

    init(vertices: [Point2]) {
        var length: CGFloat = 0
        for (i, v) in vertices.enumerated() {
            guard i + 1 < vertices.count else { break }
            length += v.distance(to: vertices[i + 1])
        }

        self.vertices = vertices
        self.length = length
    }
}
