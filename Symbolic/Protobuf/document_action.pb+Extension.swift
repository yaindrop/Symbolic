import Foundation
import SwiftProtobuf

/*
 syntax = "proto3";

 import "protobuf/symbolic.proto";

 package symbolic.pb;

 // MARK: - PathAction

 message PathAction {
   oneof kind {
     Create create = 101;
     Update update = 102;

     Delete delete = 201;
     Move move = 202;
   }

   message Create {
     UUID symbol_id = 1;
     UUID path_id = 2;
     Path path = 3;
   }

   message Update {
     UUID path_id = 1;
     oneof kind {
       AddEndingNode add_ending_node = 101;
       SplitSegment split_segment = 102;
       DeleteNodes delete_nodes = 103;

       UpdateNode update_node = 104;
       UpdateSegment update_segment = 105;

       MoveNodes move_nodes = 106;
       MoveNodeControl move_node_control = 107;

       Merge merge = 108;
       Split split = 109;

       SetName set_name = 201;
       SetNodeType set_node_type = 202;
       SetSegmentType set_segment_type = 203;
     }

     message AddEndingNode {
       UUID ending_node_id = 1;
       UUID new_node_id = 2;
       Vector2 offset = 3;
     }

     message SplitSegment {
       UUID from_node_id = 1;
       double paramT = 2;
       UUID new_node_id = 3;
       Vector2 offset = 4;
     }

     message DeleteNodes { repeated UUID node_ids = 1; }

     message UpdateNode {
       UUID node_id = 1;
       PathNode node = 2;
     }

     message UpdateSegment {
       UUID from_node_id = 1;
       PathSegment segment = 2;
     }

     message MoveNodes {
       repeated UUID node_ids = 1;
       Vector2 offset = 2;
     }

     message MoveNodeControl {
       UUID node_id = 1;
       PathNodeControlType control_type = 2;
       Vector2 offset = 3;
     }

     message Merge {
       UUID ending_node_id = 1;
       UUID merged_path_id = 2;
       UUID merged_ending_node_id = 3;
     }

     message Split {
       UUID node_id = 1;
       UUID new_path_id = 2;
       optional UUID new_node_id = 3;
     }

     message SetName { optional string name = 1; }

     message SetNodeType {
       repeated UUID node_ids = 1;
       optional PathNodeType node_type = 2;
     }

     message SetSegmentType {
       repeated UUID from_node_ids = 1;
       optional PathSegmentType segment_type = 2;
     }
   }

   message Delete { repeated UUID path_ids = 1; }

   message Move {
     repeated UUID path_ids = 1;
     Vector2 offset = 2;
   }
 }

 // MARK: - SymbolAction

 message SymbolAction {
   oneof kind {
     Create create = 101;
     Resize resize = 102;

     Delete delete = 201;
     Move move = 202;
   }

   message Create {
     UUID symbol_id = 1;
     Point2 origin = 2;
     Size2 size = 3;
   }

   message Resize {
     UUID symbol_id = 1;
     Point2 origin = 2;
     Size2 size = 3;
   }

   message Delete { repeated UUID symbol_ids = 1; }

   message Move {
     repeated UUID symbol_ids = 1;
     Vector2 offset = 2;
   }
 }

 // MARK: - ItemAction

 message ItemAction {
   message Group {
     UUID group_id = 1;
     repeated UUID members = 2;
     optional UUID in_symbol_id = 3;
     optional UUID in_group_id = 4;
   }

   message Ungroup { repeated UUID group_ids = 1; }

   message Reorder {
     UUID item_id = 1;
     UUID to_item_id = 2;
     bool is_after = 3;
   }

   oneof kind {
     Group group = 101;
     Ungroup ungroup = 102;
     Reorder reorder = 103;
   }
 }

 // MARK: - DocumentAction

 message DocumentAction {
   oneof kind {
     PathAction path_action = 101;
     SymbolAction symbol_action = 102;
     ItemAction item_action = 103;
   }
 }
 */

// MARK: - PathEvent

extension PathAction.Create: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_PathAction.Create) {
        pb.symbolID = symbolId.pb
        pb.pathID = pathId.pb
        pb.path = path.pb
    }
}

extension Symbolic_Pb_PathAction.Create: ProtobufParsable {
    func decoded() throws -> PathAction.Create {
        try .init(symbolId: symbolID.decoded(), pathId: pathID.decoded(), path: path.decoded())
    }
}

extension PathAction.Update.AddEndingNode: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_PathAction.Update.AddEndingNode) {
        pb.endingNodeID = endingNodeId.pb
        pb.newNodeID = newNodeId.pb
        pb.offset = offset.pb
    }
}

extension Symbolic_Pb_PathAction.Update.AddEndingNode: ProtobufParsable {
    func decoded() throws -> PathAction.Update.AddEndingNode {
        .init(endingNodeId: endingNodeID.decoded(), newNodeId: newNodeID.decoded(), offset: offset.decoded())
    }
}

extension PathAction.Update.SplitSegment: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_PathAction.Update.SplitSegment) {
        pb.fromNodeID = fromNodeId.pb
        pb.paramT = paramT
        pb.newNodeID = newNodeId.pb
        pb.offset = offset.pb
    }
}

extension Symbolic_Pb_PathAction.Update.SplitSegment: ProtobufParsable {
    func decoded() throws -> PathAction.Update.SplitSegment {
        .init(fromNodeId: fromNodeID.decoded(), paramT: paramT, newNodeId: newNodeID.decoded(), offset: offset.decoded())
    }
}

extension PathAction.Update.DeleteNodes: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_PathAction.Update.DeleteNodes) {
        pb.nodeIds = nodeIds.map { $0.pb }
    }
}

extension Symbolic_Pb_PathAction.Update.DeleteNodes: ProtobufParsable {
    func decoded() throws -> PathAction.Update.DeleteNodes {
        .init(nodeIds: nodeIds.map { $0.decoded() })
    }
}

extension PathAction.Update.UpdateNode: ProtobufSerializable {
    func encode(pb: inout Symbolic_Pb_PathAction.Update.UpdateNode) {
        pb.nodeID = nodeId.pb
        pb.node = node.pb
    }
}

extension Symbolic_Pb_PathAction.Update.UpdateNode: ProtobufParsable {
    func decoded() throws -> PathAction.Update.UpdateNode {
        .init(nodeId: nodeID.decoded(), node: node.decoded())
    }
}
