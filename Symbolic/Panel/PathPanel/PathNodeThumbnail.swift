import SwiftUI

// MARK: - PathNodeThumbnail

struct PathNodeThumbnail: View, TracedView {
    let path: Path, pathProperty: PathProperty, nodeId: UUID

    var body: some View { trace {
        content
    } }
}

// MARK: private

private extension PathNodeThumbnail {
    var content: some View {
        Rectangle()
            .fill(.clear)
            .overlay {
                let segmentsPath = segmentsPath,
                    cubicInPath = cubicInPath,
                    cubicOutPath = cubicOutPath,
                    paths = [segmentsPath, cubicInPath, cubicOutPath],
                    boundingRect = CGRect(union: paths.map { $0.boundingRect })!,
                    transform = CGAffineTransform(fit: boundingRect, to: .init(size))
                segmentsPath
                    .transform(transform)
                    .stroke(Color.label.opacity(0.5), style: .init(lineWidth: 2, lineCap: .round))
                cubicInPath
                    .transform(transform)
                    .stroke(.orange, style: .init(lineWidth: 1, lineCap: .round))
                cubicOutPath
                    .transform(transform)
                    .stroke(.green, style: .init(lineWidth: 1, lineCap: .round))
                nodePath(transform)
                    .stroke(.primary, style: .init(lineWidth: borderLineWidth / 2))
                    .fill(.primary.opacity(0.2))
            }
            .clipShape(border)
            .overlay { border.stroke(.primary, lineWidth: borderLineWidth) }
            .frame(size: size)
    }

    var size: CGSize { .init(20, 20) }

    var node: PathNode? { path.node(id: nodeId) }

    var nodeType: PathNodeType { pathProperty.nodeType(id: nodeId) }

    var segmentsPath: SUPath {
        SUPath {
            if let prevNodeId = path.nodeId(before: nodeId) {
                path.segment(fromId: prevNodeId)?
                    .subsegment(fromT: 0.5, toT: 1)
                    .append(to: &$0)
            }
            path.segment(fromId: nodeId)?
                .subsegment(fromT: 0, toT: 0.5)
                .append(to: &$0)
        }
    }

    var cubicInPath: SUPath {
        SUPath {
            guard let node else { return }
            $0.move(to: node.position)
            $0.addLine(to: node.positionIn)
        }
    }

    var cubicOutPath: SUPath {
        SUPath {
            guard let node else { return }
            $0.move(to: node.position)
            $0.addLine(to: node.positionOut)
        }
    }

    func nodePath(_ transform: CGAffineTransform) -> SUPath {
        SUPath {
            guard let node else { return }
            let rect = CGRect(center: node.position.applying(transform), size: .init(squared: 4))
            $0.addRoundedRect(in: rect, cornerSize: .init(squared: nodeType == .corner ? 1 : 2))
        }
    }

    var border: AnyShape {
        .init(RoundedRectangle(cornerRadius: nodeType == .corner ? 4 : size.width / 2))
    }

    var borderLineWidth: Scalar {
        nodeType == .mirrored ? 2 : 1
    }
}

// MARK: - PathNodeIcon

struct PathNodeIcon: View, TracedView {
    let nodeId: UUID

    var body: some View { trace {
        content
    } }
}

// MARK: private

private extension PathNodeIcon {
    var content: some View {
        VStack(spacing: 0) {
            Image(systemName: "smallcircle.filled.circle")
                .font(.callout)
            Spacer(minLength: 0)
            Text(nodeId.shortDescription)
                .font(.system(size: 10).monospaced())
        }
        .frame(width: 32, height: 32)
    }
}

// MARK: - PathSegmentIcon

struct PathSegmentIcon: View, TracedView {
    let fromNodeId: UUID, toNodeId: UUID, isOut: Bool?

    var body: some View { trace {
        content
    } }
}

// MARK: private

private extension PathSegmentIcon {
    var content: some View {
        HStack(spacing: 0) {
            PathNodeIcon(nodeId: fromNodeId)
                .scaleEffect(isOut != false ? 1 : 0.9)
                .opacity(isOut != false ? 1 : 0.5)
            Image(systemName: "arrow.forward")
                .font(.caption)
                .padding(6)
            PathNodeIcon(nodeId: toNodeId)
                .scaleEffect(isOut != true ? 1 : 0.9)
                .opacity(isOut != true ? 1 : 0.5)
        }
    }
}
