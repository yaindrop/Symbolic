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
                    controlInPath = controlInPath,
                    controlOutPath = controlOutPath,
                    paths = [segmentsPath, controlInPath, controlOutPath],
                    boundingRect = CGRect(union: paths.map { $0.boundingRect })!,
                    transform = CGAffineTransform(fit: boundingRect, to: .init(size))
                segmentsPath
                    .transform(transform)
                    .stroke(Color.label.opacity(0.5), style: .init(lineWidth: 2, lineCap: .round))
                controlInPath
                    .transform(transform)
                    .stroke(.orange, style: .init(lineWidth: 1, lineCap: .round))
                controlOutPath
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

    var controlInPath: SUPath {
        SUPath {
            guard let node = path.node(id: nodeId) else { return }
            $0.move(to: node.position)
            $0.addLine(to: node.positionIn)
        }
    }

    var controlOutPath: SUPath {
        SUPath {
            guard let node = path.node(id: nodeId) else { return }
            $0.move(to: node.position)
            $0.addLine(to: node.positionOut)
        }
    }

    func nodePath(_ transform: CGAffineTransform) -> SUPath {
        SUPath {
            guard let node = path.node(id: nodeId) else { return }
            let rect = CGRect(center: node.position.applying(transform), size: .init(squared: 4))
            switch pathProperty.nodeType(id: nodeId) {
            case .corner: $0.addRoundedRect(in: rect, cornerSize: .init(squared: 1))
            case .locked, .mirrored: $0.addEllipse(in: rect)
            }
        }
    }

    var border: AnyShape {
        switch pathProperty.nodeType(id: nodeId) {
        case .corner: .init(RoundedRectangle(cornerRadius: 4))
        case .locked, .mirrored: .init(Circle())
        }
    }

    var borderLineWidth: Scalar {
        switch pathProperty.nodeType(id: nodeId) {
        case .corner, .locked: 1
        case .mirrored: 2
        }
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

// MARK: - PathCurveIcon

struct PathCurveIcon: View, TracedView {
    let fromNodeId: UUID, toNodeId: UUID, isOut: Bool

    var body: some View { trace {
        content
    } }
}

// MARK: private

private extension PathCurveIcon {
    var content: some View {
        HStack(spacing: 0) {
            PathNodeIcon(nodeId: fromNodeId)
                .scaleEffect(isOut ? 1 : 0.9)
                .opacity(isOut ? 1 : 0.5)
            Image(systemName: "arrow.forward")
                .font(.caption)
                .padding(6)
            PathNodeIcon(nodeId: toNodeId)
                .scaleEffect(isOut ? 0.9 : 1)
                .opacity(isOut ? 0.5 : 1)
        }
    }
}
