import FlatBuffers
import Foundation

protocol StructSerializable {
    associatedtype T: NativeStruct
    var serialized: T { get }
}

extension FlatBufferBuilder {
    mutating func createVector<T: StructSerializable>(of serializables: [T]) -> Offset {
        createVector(ofStructs: serializables.map { $0.serialized })
    }
}

// MARK: - UUID

extension UUID: StructSerializable {
    var serialized: FB_UUID {
        FB_UUID.init <- uuid
    }
}

extension FB_UUID {
    var deserialized: UUID {
        let uuidFormat = "%02X%02X%02X%02X-%02X%02X-%02X%02X-%02X%02X-%02X%02X%02X%02X%02X%02X"
        let uuidString = String(format: uuidFormat, u0, u1, u2, u3, u4, u5, u6, u7, u8, u9, u10, u11, u12, u13, u14, u15)
        return .init(uuidString: uuidString)!
    }
}

// MARK: - Date

extension Date: StructSerializable {
    var serialized: FB_Date {
        .init(timestampNs: .init(timeIntervalSince1970 * Double(NSEC_PER_SEC)))
    }
}

extension FB_Date {
    var deserialized: Date {
        .init(timeIntervalSince1970: Double(timestampNs) / Double(NSEC_PER_SEC))
    }
}

// MARK: - Vector2

extension Vector2: StructSerializable {
    var serialized: FB_Vector2 {
        .init(x: .init(dx), y: .init(dy))
    }
}

extension Point2: StructSerializable {
    var serialized: FB_Vector2 {
        .init(x: .init(x), y: .init(y))
    }
}

extension FB_Vector2 {
    var deserialized: Vector2 {
        .init(Scalar(x), Scalar(y))
    }

    var point: Point2 {
        .init(Scalar(x), Scalar(y))
    }
}

// MARK: - PathNode

extension PathNode: StructSerializable {
    var serialized: FB_PathNode {
        .init(position: position.serialized, cubicIn: cubicIn.serialized, cubicOut: cubicOut.serialized)
    }
}

extension FB_PathNode {
    var deserialized: PathNode {
        .init(position: position.point, cubicIn: cubicIn.deserialized, cubicOut: cubicOut.deserialized)
    }
}

// MARK: - Path

extension Path {
    func serialize(to fbb: inout FlatBufferBuilder) -> Offset {
        FB_Path.createPath(
            &fbb,
            nodeIdsVectorOffset: fbb.createVector(of: nodeIds),
            nodesVectorOffset: fbb.createVector(of: nodes),
            isClosed: isClosed
        )
    }
}

extension FB_Path {
    var deserialized: Path? {
        guard nodeIdsCount == nodesCount else { return nil }
        let nodeIds = (0 ... nodeIdsCount).map { self.nodeIds(at: $0) }.complete(),
            nodes = (0 ... nodesCount).map { self.nodes(at: $0) }.complete()
        guard let nodeIds, let nodes else { return nil }
        var nodeMap = Path.NodeMap()
        for i in nodeIds.indices {
            nodeMap[nodeIds[i].deserialized] = nodes[i].deserialized
        }
        return .init(nodeMap: nodeMap, isClosed: isClosed)
    }
}

// MARK: PathEvent.Update

protocol PathEvent_Update_Kind_Deserializable: FlatbuffersInitializable {
    var deserialized: PathEvent.Update.Kind { get }
}

extension PathEvent.Update.Move {
    func serialize(to fbb: inout FlatBufferBuilder) -> Offset {
        FB_PathEvent_Update_Move.createMove(
            &fbb,
            offset: offset.serialized
        )
    }
}

extension FB_PathEvent_Update_Move: PathEvent_Update_Kind_Deserializable {
    var deserialized: PathEvent.Update.Kind {
        .move(.init(offset: offset.deserialized))
    }
}

// MARK: PathEvent.Update.NodeCreate

extension PathEvent.Update.NodeCreate {
    func serialize(to fbb: inout FlatBufferBuilder) -> Offset {
        FB_PathEvent_Update_NodeCreate.createNodeCreate(
            &fbb,
            prevNodeId: prevNodeId?.serialized,
            nodeId: nodeId.serialized,
            node: node.serialized
        )
    }
}

extension FB_PathEvent_Update_NodeCreate: PathEvent_Update_Kind_Deserializable {
    var deserialized: PathEvent.Update.Kind {
        .nodeCreate(.init(prevNodeId: prevNodeId?.deserialized, nodeId: nodeId.deserialized, node: node.deserialized))
    }
}

// MARK: PathEvent.Update.NodeDelete

extension PathEvent.Update.NodeDelete {
    func serialize(to fbb: inout FlatBufferBuilder) -> Offset {
        FB_PathEvent_Update_NodeDelete.createNodeDelete(
            &fbb,
            nodeId: nodeId.serialized
        )
    }
}

extension FB_PathEvent_Update_NodeDelete: PathEvent_Update_Kind_Deserializable {
    var deserialized: PathEvent.Update.Kind {
        .nodeDelete(.init(nodeId: nodeId.deserialized))
    }
}

// MARK: PathEvent.Update.NodeUpdate

extension PathEvent.Update.NodeUpdate {
    func serialize(to fbb: inout FlatBufferBuilder) -> Offset {
        FB_PathEvent_Update_NodeUpdate.createNodeUpdate(
            &fbb,
            nodeId: nodeId.serialized,
            node: node.serialized
        )
    }
}

extension FB_PathEvent_Update_NodeUpdate: PathEvent_Update_Kind_Deserializable {
    var deserialized: PathEvent.Update.Kind {
        .nodeUpdate(.init(nodeId: nodeId.deserialized, node: node.deserialized))
    }
}

// MARK: PathEvent.Update.Kind

extension PathEvent.Update.Kind {
    var serializedType: FB_PathEvent_Update_Kind {
        switch self {
        case .move: .move
        case .nodeCreate: .nodecreate
        case .nodeDelete: .nodedelete
        case .nodeUpdate: .nodeupdate
        }
    }

    func serialize(to fbb: inout FlatBufferBuilder) -> Offset {
        switch self {
        case let .move(kind): kind.serialize(to: &fbb)
        case let .nodeCreate(kind): kind.serialize(to: &fbb)
        case let .nodeDelete(kind): kind.serialize(to: &fbb)
        case let .nodeUpdate(kind): kind.serialize(to: &fbb)
        }
    }
}

extension FB_PathEvent_Update_Kind {
    var deserializedType: PathEvent_Update_Kind_Deserializable.Type {
        switch self {
        case .move: FB_PathEvent_Update_Move.self
        case .nodecreate: FB_PathEvent_Update_NodeCreate.self
        case .nodedelete: FB_PathEvent_Update_NodeDelete.self
        case .nodeupdate: FB_PathEvent_Update_NodeUpdate.self
        case .none_: fatalError()
        }
    }
}

extension PathEvent.Update {
    func serialize(to fbb: inout FlatBufferBuilder) -> Offset {
        FB_PathEvent_Update.createUpdate(
            &fbb,
            pathId: pathId.serialized,
            kindsTypeVectorOffset: fbb.createVector(kinds.map { $0.serializedType }),
            kindsVectorOffset: fbb.createVector(ofOffsets: kinds.map { $0.serialize(to: &fbb) })
        )
    }
}

extension FB_PathEvent_Update {
    var deserialized: PathEvent.Update? {
        var kinds: [PathEvent.Update.Kind] = []
        for i in 0 ... kindsTypeCount {
            guard let kindType = kindsType(at: i),
                  let kind = self.kinds(at: i, type: kindType.deserializedType) else { return nil }
            kinds.append(kind.deserialized)
        }
        return .init(pathId: pathId.deserialized, kinds: kinds)
    }
}
