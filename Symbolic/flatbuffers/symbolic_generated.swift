// automatically generated by the FlatBuffers compiler, do not modify
// swiftlint:disable all
// swiftformat:disable all

import FlatBuffers

public enum Symbolic_PathEvent: UInt8, UnionEnum {
  public typealias T = UInt8

  public init?(value: T) {
    self.init(rawValue: value)
  }

  public static var byteSize: Int { return MemoryLayout<UInt8>.size }
  public var value: UInt8 { return self.rawValue }
  case none_ = 0
  case patheventCreate = 1
  case patheventDelete = 2
  case patheventUpdate = 3

  public static var max: Symbolic_PathEvent { return .patheventUpdate }
  public static var min: Symbolic_PathEvent { return .none_ }
}


public enum Symbolic_PathEvent_Update_Kind: UInt8, UnionEnum {
  public typealias T = UInt8

  public init?(value: T) {
    self.init(rawValue: value)
  }

  public static var byteSize: Int { return MemoryLayout<UInt8>.size }
  public var value: UInt8 { return self.rawValue }
  case none_ = 0
  case patheventUpdateMove = 1
  case patheventUpdateNodecreate = 2
  case patheventUpdateNodedelete = 3
  case patheventUpdateNodeupdate = 4

  public static var max: Symbolic_PathEvent_Update_Kind { return .patheventUpdateNodeupdate }
  public static var min: Symbolic_PathEvent_Update_Kind { return .none_ }
}


public struct Symbolic_UUID: FlatBufferObject, Verifiable {

  static func validateVersion() { FlatBuffersVersion_24_3_25() }
  public var __buffer: ByteBuffer! { return _accessor.bb }
  private var _accessor: Table

  private init(_ t: Table) { _accessor = t }
  public init(_ bb: ByteBuffer, o: Int32) { _accessor = Table(bb: bb, position: o) }

  private enum VTOFFSET: VOffset {
    case u0 = 4
    case u1 = 6
    case u2 = 8
    case u3 = 10
    case u4 = 12
    case u5 = 14
    case u6 = 16
    case u7 = 18
    var v: Int32 { Int32(self.rawValue) }
    var p: VOffset { self.rawValue }
  }

  public var u0: UInt8 { let o = _accessor.offset(VTOFFSET.u0.v); return o == 0 ? 0 : _accessor.readBuffer(of: UInt8.self, at: o) }
  public var u1: UInt8 { let o = _accessor.offset(VTOFFSET.u1.v); return o == 0 ? 0 : _accessor.readBuffer(of: UInt8.self, at: o) }
  public var u2: UInt8 { let o = _accessor.offset(VTOFFSET.u2.v); return o == 0 ? 0 : _accessor.readBuffer(of: UInt8.self, at: o) }
  public var u3: UInt8 { let o = _accessor.offset(VTOFFSET.u3.v); return o == 0 ? 0 : _accessor.readBuffer(of: UInt8.self, at: o) }
  public var u4: UInt8 { let o = _accessor.offset(VTOFFSET.u4.v); return o == 0 ? 0 : _accessor.readBuffer(of: UInt8.self, at: o) }
  public var u5: UInt8 { let o = _accessor.offset(VTOFFSET.u5.v); return o == 0 ? 0 : _accessor.readBuffer(of: UInt8.self, at: o) }
  public var u6: UInt8 { let o = _accessor.offset(VTOFFSET.u6.v); return o == 0 ? 0 : _accessor.readBuffer(of: UInt8.self, at: o) }
  public var u7: UInt8 { let o = _accessor.offset(VTOFFSET.u7.v); return o == 0 ? 0 : _accessor.readBuffer(of: UInt8.self, at: o) }
  public static func startUUID(_ fbb: inout FlatBufferBuilder) -> UOffset { fbb.startTable(with: 8) }
  public static func add(u0: UInt8, _ fbb: inout FlatBufferBuilder) { fbb.add(element: u0, def: 0, at: VTOFFSET.u0.p) }
  public static func add(u1: UInt8, _ fbb: inout FlatBufferBuilder) { fbb.add(element: u1, def: 0, at: VTOFFSET.u1.p) }
  public static func add(u2: UInt8, _ fbb: inout FlatBufferBuilder) { fbb.add(element: u2, def: 0, at: VTOFFSET.u2.p) }
  public static func add(u3: UInt8, _ fbb: inout FlatBufferBuilder) { fbb.add(element: u3, def: 0, at: VTOFFSET.u3.p) }
  public static func add(u4: UInt8, _ fbb: inout FlatBufferBuilder) { fbb.add(element: u4, def: 0, at: VTOFFSET.u4.p) }
  public static func add(u5: UInt8, _ fbb: inout FlatBufferBuilder) { fbb.add(element: u5, def: 0, at: VTOFFSET.u5.p) }
  public static func add(u6: UInt8, _ fbb: inout FlatBufferBuilder) { fbb.add(element: u6, def: 0, at: VTOFFSET.u6.p) }
  public static func add(u7: UInt8, _ fbb: inout FlatBufferBuilder) { fbb.add(element: u7, def: 0, at: VTOFFSET.u7.p) }
  public static func endUUID(_ fbb: inout FlatBufferBuilder, start: UOffset) -> Offset { let end = Offset(offset: fbb.endTable(at: start)); return end }
  public static func createUUID(
    _ fbb: inout FlatBufferBuilder,
    u0: UInt8 = 0,
    u1: UInt8 = 0,
    u2: UInt8 = 0,
    u3: UInt8 = 0,
    u4: UInt8 = 0,
    u5: UInt8 = 0,
    u6: UInt8 = 0,
    u7: UInt8 = 0
  ) -> Offset {
    let __start = Symbolic_UUID.startUUID(&fbb)
    Symbolic_UUID.add(u0: u0, &fbb)
    Symbolic_UUID.add(u1: u1, &fbb)
    Symbolic_UUID.add(u2: u2, &fbb)
    Symbolic_UUID.add(u3: u3, &fbb)
    Symbolic_UUID.add(u4: u4, &fbb)
    Symbolic_UUID.add(u5: u5, &fbb)
    Symbolic_UUID.add(u6: u6, &fbb)
    Symbolic_UUID.add(u7: u7, &fbb)
    return Symbolic_UUID.endUUID(&fbb, start: __start)
  }

  public static func verify<T>(_ verifier: inout Verifier, at position: Int, of type: T.Type) throws where T: Verifiable {
    var _v = try verifier.visitTable(at: position)
    try _v.visit(field: VTOFFSET.u0.p, fieldName: "u0", required: false, type: UInt8.self)
    try _v.visit(field: VTOFFSET.u1.p, fieldName: "u1", required: false, type: UInt8.self)
    try _v.visit(field: VTOFFSET.u2.p, fieldName: "u2", required: false, type: UInt8.self)
    try _v.visit(field: VTOFFSET.u3.p, fieldName: "u3", required: false, type: UInt8.self)
    try _v.visit(field: VTOFFSET.u4.p, fieldName: "u4", required: false, type: UInt8.self)
    try _v.visit(field: VTOFFSET.u5.p, fieldName: "u5", required: false, type: UInt8.self)
    try _v.visit(field: VTOFFSET.u6.p, fieldName: "u6", required: false, type: UInt8.self)
    try _v.visit(field: VTOFFSET.u7.p, fieldName: "u7", required: false, type: UInt8.self)
    _v.finish()
  }
}

public struct Symbolic_Vector2: FlatBufferObject, Verifiable {

  static func validateVersion() { FlatBuffersVersion_24_3_25() }
  public var __buffer: ByteBuffer! { return _accessor.bb }
  private var _accessor: Table

  private init(_ t: Table) { _accessor = t }
  public init(_ bb: ByteBuffer, o: Int32) { _accessor = Table(bb: bb, position: o) }

  private enum VTOFFSET: VOffset {
    case x = 4
    case y = 6
    var v: Int32 { Int32(self.rawValue) }
    var p: VOffset { self.rawValue }
  }

  public var x: Float32 { let o = _accessor.offset(VTOFFSET.x.v); return o == 0 ? 0.0 : _accessor.readBuffer(of: Float32.self, at: o) }
  public var y: Float32 { let o = _accessor.offset(VTOFFSET.y.v); return o == 0 ? 0.0 : _accessor.readBuffer(of: Float32.self, at: o) }
  public static func startVector2(_ fbb: inout FlatBufferBuilder) -> UOffset { fbb.startTable(with: 2) }
  public static func add(x: Float32, _ fbb: inout FlatBufferBuilder) { fbb.add(element: x, def: 0.0, at: VTOFFSET.x.p) }
  public static func add(y: Float32, _ fbb: inout FlatBufferBuilder) { fbb.add(element: y, def: 0.0, at: VTOFFSET.y.p) }
  public static func endVector2(_ fbb: inout FlatBufferBuilder, start: UOffset) -> Offset { let end = Offset(offset: fbb.endTable(at: start)); return end }
  public static func createVector2(
    _ fbb: inout FlatBufferBuilder,
    x: Float32 = 0.0,
    y: Float32 = 0.0
  ) -> Offset {
    let __start = Symbolic_Vector2.startVector2(&fbb)
    Symbolic_Vector2.add(x: x, &fbb)
    Symbolic_Vector2.add(y: y, &fbb)
    return Symbolic_Vector2.endVector2(&fbb, start: __start)
  }

  public static func verify<T>(_ verifier: inout Verifier, at position: Int, of type: T.Type) throws where T: Verifiable {
    var _v = try verifier.visitTable(at: position)
    try _v.visit(field: VTOFFSET.x.p, fieldName: "x", required: false, type: Float32.self)
    try _v.visit(field: VTOFFSET.y.p, fieldName: "y", required: false, type: Float32.self)
    _v.finish()
  }
}

public struct Symbolic_PathNode: FlatBufferObject, Verifiable {

  static func validateVersion() { FlatBuffersVersion_24_3_25() }
  public var __buffer: ByteBuffer! { return _accessor.bb }
  private var _accessor: Table

  private init(_ t: Table) { _accessor = t }
  public init(_ bb: ByteBuffer, o: Int32) { _accessor = Table(bb: bb, position: o) }

  private enum VTOFFSET: VOffset {
    case position = 4
    case cubicIn = 6
    case cubicOut = 8
    var v: Int32 { Int32(self.rawValue) }
    var p: VOffset { self.rawValue }
  }

  public var position: Symbolic_Vector2? { let o = _accessor.offset(VTOFFSET.position.v); return o == 0 ? nil : Symbolic_Vector2(_accessor.bb, o: _accessor.indirect(o + _accessor.postion)) }
  public var cubicIn: Symbolic_Vector2? { let o = _accessor.offset(VTOFFSET.cubicIn.v); return o == 0 ? nil : Symbolic_Vector2(_accessor.bb, o: _accessor.indirect(o + _accessor.postion)) }
  public var cubicOut: Symbolic_Vector2? { let o = _accessor.offset(VTOFFSET.cubicOut.v); return o == 0 ? nil : Symbolic_Vector2(_accessor.bb, o: _accessor.indirect(o + _accessor.postion)) }
  public static func startPathNode(_ fbb: inout FlatBufferBuilder) -> UOffset { fbb.startTable(with: 3) }
  public static func add(position: Offset, _ fbb: inout FlatBufferBuilder) { fbb.add(offset: position, at: VTOFFSET.position.p) }
  public static func add(cubicIn: Offset, _ fbb: inout FlatBufferBuilder) { fbb.add(offset: cubicIn, at: VTOFFSET.cubicIn.p) }
  public static func add(cubicOut: Offset, _ fbb: inout FlatBufferBuilder) { fbb.add(offset: cubicOut, at: VTOFFSET.cubicOut.p) }
  public static func endPathNode(_ fbb: inout FlatBufferBuilder, start: UOffset) -> Offset { let end = Offset(offset: fbb.endTable(at: start)); return end }
  public static func createPathNode(
    _ fbb: inout FlatBufferBuilder,
    positionOffset position: Offset = Offset(),
    cubicInOffset cubicIn: Offset = Offset(),
    cubicOutOffset cubicOut: Offset = Offset()
  ) -> Offset {
    let __start = Symbolic_PathNode.startPathNode(&fbb)
    Symbolic_PathNode.add(position: position, &fbb)
    Symbolic_PathNode.add(cubicIn: cubicIn, &fbb)
    Symbolic_PathNode.add(cubicOut: cubicOut, &fbb)
    return Symbolic_PathNode.endPathNode(&fbb, start: __start)
  }

  public static func verify<T>(_ verifier: inout Verifier, at position: Int, of type: T.Type) throws where T: Verifiable {
    var _v = try verifier.visitTable(at: position)
    try _v.visit(field: VTOFFSET.position.p, fieldName: "position", required: false, type: ForwardOffset<Symbolic_Vector2>.self)
    try _v.visit(field: VTOFFSET.cubicIn.p, fieldName: "cubicIn", required: false, type: ForwardOffset<Symbolic_Vector2>.self)
    try _v.visit(field: VTOFFSET.cubicOut.p, fieldName: "cubicOut", required: false, type: ForwardOffset<Symbolic_Vector2>.self)
    _v.finish()
  }
}

public struct Symbolic_Path: FlatBufferObject, Verifiable {

  static func validateVersion() { FlatBuffersVersion_24_3_25() }
  public var __buffer: ByteBuffer! { return _accessor.bb }
  private var _accessor: Table

  private init(_ t: Table) { _accessor = t }
  public init(_ bb: ByteBuffer, o: Int32) { _accessor = Table(bb: bb, position: o) }

  private enum VTOFFSET: VOffset {
    case id = 4
    case nodeIds = 6
    case nodes = 8
    case isClosed = 10
    var v: Int32 { Int32(self.rawValue) }
    var p: VOffset { self.rawValue }
  }

  public var id: Symbolic_UUID? { let o = _accessor.offset(VTOFFSET.id.v); return o == 0 ? nil : Symbolic_UUID(_accessor.bb, o: _accessor.indirect(o + _accessor.postion)) }
  public var hasNodeIds: Bool { let o = _accessor.offset(VTOFFSET.nodeIds.v); return o == 0 ? false : true }
  public var nodeIdsCount: Int32 { let o = _accessor.offset(VTOFFSET.nodeIds.v); return o == 0 ? 0 : _accessor.vector(count: o) }
  public func nodeIds(at index: Int32) -> Symbolic_UUID? { let o = _accessor.offset(VTOFFSET.nodeIds.v); return o == 0 ? nil : Symbolic_UUID(_accessor.bb, o: _accessor.indirect(_accessor.vector(at: o) + index * 4)) }
  public var hasNodes: Bool { let o = _accessor.offset(VTOFFSET.nodes.v); return o == 0 ? false : true }
  public var nodesCount: Int32 { let o = _accessor.offset(VTOFFSET.nodes.v); return o == 0 ? 0 : _accessor.vector(count: o) }
  public func nodes(at index: Int32) -> Symbolic_PathNode? { let o = _accessor.offset(VTOFFSET.nodes.v); return o == 0 ? nil : Symbolic_PathNode(_accessor.bb, o: _accessor.indirect(_accessor.vector(at: o) + index * 4)) }
  public var isClosed: Bool { let o = _accessor.offset(VTOFFSET.isClosed.v); return o == 0 ? false : _accessor.readBuffer(of: Bool.self, at: o) }
  public static func startPath(_ fbb: inout FlatBufferBuilder) -> UOffset { fbb.startTable(with: 4) }
  public static func add(id: Offset, _ fbb: inout FlatBufferBuilder) { fbb.add(offset: id, at: VTOFFSET.id.p) }
  public static func addVectorOf(nodeIds: Offset, _ fbb: inout FlatBufferBuilder) { fbb.add(offset: nodeIds, at: VTOFFSET.nodeIds.p) }
  public static func addVectorOf(nodes: Offset, _ fbb: inout FlatBufferBuilder) { fbb.add(offset: nodes, at: VTOFFSET.nodes.p) }
  public static func add(isClosed: Bool, _ fbb: inout FlatBufferBuilder) { fbb.add(element: isClosed, def: false,
   at: VTOFFSET.isClosed.p) }
  public static func endPath(_ fbb: inout FlatBufferBuilder, start: UOffset) -> Offset { let end = Offset(offset: fbb.endTable(at: start)); return end }
  public static func createPath(
    _ fbb: inout FlatBufferBuilder,
    idOffset id: Offset = Offset(),
    nodeIdsVectorOffset nodeIds: Offset = Offset(),
    nodesVectorOffset nodes: Offset = Offset(),
    isClosed: Bool = false
  ) -> Offset {
    let __start = Symbolic_Path.startPath(&fbb)
    Symbolic_Path.add(id: id, &fbb)
    Symbolic_Path.addVectorOf(nodeIds: nodeIds, &fbb)
    Symbolic_Path.addVectorOf(nodes: nodes, &fbb)
    Symbolic_Path.add(isClosed: isClosed, &fbb)
    return Symbolic_Path.endPath(&fbb, start: __start)
  }

  public static func verify<T>(_ verifier: inout Verifier, at position: Int, of type: T.Type) throws where T: Verifiable {
    var _v = try verifier.visitTable(at: position)
    try _v.visit(field: VTOFFSET.id.p, fieldName: "id", required: false, type: ForwardOffset<Symbolic_UUID>.self)
    try _v.visit(field: VTOFFSET.nodeIds.p, fieldName: "nodeIds", required: false, type: ForwardOffset<Vector<ForwardOffset<Symbolic_UUID>, Symbolic_UUID>>.self)
    try _v.visit(field: VTOFFSET.nodes.p, fieldName: "nodes", required: false, type: ForwardOffset<Vector<ForwardOffset<Symbolic_PathNode>, Symbolic_PathNode>>.self)
    try _v.visit(field: VTOFFSET.isClosed.p, fieldName: "isClosed", required: false, type: Bool.self)
    _v.finish()
  }
}

public struct Symbolic_PathEvent_Create: FlatBufferObject, Verifiable {

  static func validateVersion() { FlatBuffersVersion_24_3_25() }
  public var __buffer: ByteBuffer! { return _accessor.bb }
  private var _accessor: Table

  private init(_ t: Table) { _accessor = t }
  public init(_ bb: ByteBuffer, o: Int32) { _accessor = Table(bb: bb, position: o) }

  private enum VTOFFSET: VOffset {
    case path = 4
    var v: Int32 { Int32(self.rawValue) }
    var p: VOffset { self.rawValue }
  }

  public var path: Symbolic_Path? { let o = _accessor.offset(VTOFFSET.path.v); return o == 0 ? nil : Symbolic_Path(_accessor.bb, o: _accessor.indirect(o + _accessor.postion)) }
  public static func startPathEvent_Create(_ fbb: inout FlatBufferBuilder) -> UOffset { fbb.startTable(with: 1) }
  public static func add(path: Offset, _ fbb: inout FlatBufferBuilder) { fbb.add(offset: path, at: VTOFFSET.path.p) }
  public static func endPathEvent_Create(_ fbb: inout FlatBufferBuilder, start: UOffset) -> Offset { let end = Offset(offset: fbb.endTable(at: start)); return end }
  public static func createPathEvent_Create(
    _ fbb: inout FlatBufferBuilder,
    pathOffset path: Offset = Offset()
  ) -> Offset {
    let __start = Symbolic_PathEvent_Create.startPathEvent_Create(&fbb)
    Symbolic_PathEvent_Create.add(path: path, &fbb)
    return Symbolic_PathEvent_Create.endPathEvent_Create(&fbb, start: __start)
  }

  public static func verify<T>(_ verifier: inout Verifier, at position: Int, of type: T.Type) throws where T: Verifiable {
    var _v = try verifier.visitTable(at: position)
    try _v.visit(field: VTOFFSET.path.p, fieldName: "path", required: false, type: ForwardOffset<Symbolic_Path>.self)
    _v.finish()
  }
}

public struct Symbolic_PathEvent_Delete: FlatBufferObject, Verifiable {

  static func validateVersion() { FlatBuffersVersion_24_3_25() }
  public var __buffer: ByteBuffer! { return _accessor.bb }
  private var _accessor: Table

  private init(_ t: Table) { _accessor = t }
  public init(_ bb: ByteBuffer, o: Int32) { _accessor = Table(bb: bb, position: o) }

  private enum VTOFFSET: VOffset {
    case pathId = 4
    var v: Int32 { Int32(self.rawValue) }
    var p: VOffset { self.rawValue }
  }

  public var pathId: Symbolic_UUID? { let o = _accessor.offset(VTOFFSET.pathId.v); return o == 0 ? nil : Symbolic_UUID(_accessor.bb, o: _accessor.indirect(o + _accessor.postion)) }
  public static func startPathEvent_Delete(_ fbb: inout FlatBufferBuilder) -> UOffset { fbb.startTable(with: 1) }
  public static func add(pathId: Offset, _ fbb: inout FlatBufferBuilder) { fbb.add(offset: pathId, at: VTOFFSET.pathId.p) }
  public static func endPathEvent_Delete(_ fbb: inout FlatBufferBuilder, start: UOffset) -> Offset { let end = Offset(offset: fbb.endTable(at: start)); return end }
  public static func createPathEvent_Delete(
    _ fbb: inout FlatBufferBuilder,
    pathIdOffset pathId: Offset = Offset()
  ) -> Offset {
    let __start = Symbolic_PathEvent_Delete.startPathEvent_Delete(&fbb)
    Symbolic_PathEvent_Delete.add(pathId: pathId, &fbb)
    return Symbolic_PathEvent_Delete.endPathEvent_Delete(&fbb, start: __start)
  }

  public static func verify<T>(_ verifier: inout Verifier, at position: Int, of type: T.Type) throws where T: Verifiable {
    var _v = try verifier.visitTable(at: position)
    try _v.visit(field: VTOFFSET.pathId.p, fieldName: "pathId", required: false, type: ForwardOffset<Symbolic_UUID>.self)
    _v.finish()
  }
}

public struct Symbolic_PathEvent_Update: FlatBufferObject, Verifiable {

  static func validateVersion() { FlatBuffersVersion_24_3_25() }
  public var __buffer: ByteBuffer! { return _accessor.bb }
  private var _accessor: Table

  private init(_ t: Table) { _accessor = t }
  public init(_ bb: ByteBuffer, o: Int32) { _accessor = Table(bb: bb, position: o) }

  private enum VTOFFSET: VOffset {
    case pathId = 4
    case kindsType = 6
    case kinds = 8
    var v: Int32 { Int32(self.rawValue) }
    var p: VOffset { self.rawValue }
  }

  public var pathId: Symbolic_UUID? { let o = _accessor.offset(VTOFFSET.pathId.v); return o == 0 ? nil : Symbolic_UUID(_accessor.bb, o: _accessor.indirect(o + _accessor.postion)) }
  public var hasKindsType: Bool { let o = _accessor.offset(VTOFFSET.kindsType.v); return o == 0 ? false : true }
  public var kindsTypeCount: Int32 { let o = _accessor.offset(VTOFFSET.kindsType.v); return o == 0 ? 0 : _accessor.vector(count: o) }
  public func kindsType(at index: Int32) -> Symbolic_PathEvent_Update_Kind? { let o = _accessor.offset(VTOFFSET.kindsType.v); return o == 0 ? Symbolic_PathEvent_Update_Kind.none_ : Symbolic_PathEvent_Update_Kind(rawValue: _accessor.directRead(of: UInt8.self, offset: _accessor.vector(at: o) + index * 1)) }
  public var hasKinds: Bool { let o = _accessor.offset(VTOFFSET.kinds.v); return o == 0 ? false : true }
  public var kindsCount: Int32 { let o = _accessor.offset(VTOFFSET.kinds.v); return o == 0 ? 0 : _accessor.vector(count: o) }
  public func kinds<T: FlatbuffersInitializable>(at index: Int32, type: T.Type) -> T? { let o = _accessor.offset(VTOFFSET.kinds.v); return o == 0 ? nil : _accessor.directUnion(_accessor.vector(at: o) + index * 4) }
  public static func startPathEvent_Update(_ fbb: inout FlatBufferBuilder) -> UOffset { fbb.startTable(with: 3) }
  public static func add(pathId: Offset, _ fbb: inout FlatBufferBuilder) { fbb.add(offset: pathId, at: VTOFFSET.pathId.p) }
  public static func addVectorOf(kindsType: Offset, _ fbb: inout FlatBufferBuilder) { fbb.add(offset: kindsType, at: VTOFFSET.kindsType.p) }
  public static func addVectorOf(kinds: Offset, _ fbb: inout FlatBufferBuilder) { fbb.add(offset: kinds, at: VTOFFSET.kinds.p) }
  public static func endPathEvent_Update(_ fbb: inout FlatBufferBuilder, start: UOffset) -> Offset { let end = Offset(offset: fbb.endTable(at: start)); return end }
  public static func createPathEvent_Update(
    _ fbb: inout FlatBufferBuilder,
    pathIdOffset pathId: Offset = Offset(),
    kindsTypeVectorOffset kindsType: Offset = Offset(),
    kindsVectorOffset kinds: Offset = Offset()
  ) -> Offset {
    let __start = Symbolic_PathEvent_Update.startPathEvent_Update(&fbb)
    Symbolic_PathEvent_Update.add(pathId: pathId, &fbb)
    Symbolic_PathEvent_Update.addVectorOf(kindsType: kindsType, &fbb)
    Symbolic_PathEvent_Update.addVectorOf(kinds: kinds, &fbb)
    return Symbolic_PathEvent_Update.endPathEvent_Update(&fbb, start: __start)
  }

  public static func verify<T>(_ verifier: inout Verifier, at position: Int, of type: T.Type) throws where T: Verifiable {
    var _v = try verifier.visitTable(at: position)
    try _v.visit(field: VTOFFSET.pathId.p, fieldName: "pathId", required: false, type: ForwardOffset<Symbolic_UUID>.self)
    try _v.visitUnionVector(unionKey: VTOFFSET.kindsType.p, unionField: VTOFFSET.kinds.p, unionKeyName: "kindsType", fieldName: "kinds", required: false, completion: { (verifier, key: Symbolic_PathEvent_Update_Kind, pos) in
      switch key {
      case .none_:
        break // NOTE - SWIFT doesnt support none
      case .patheventUpdateMove:
        try ForwardOffset<Symbolic_PathEvent_Update_Move>.verify(&verifier, at: pos, of: Symbolic_PathEvent_Update_Move.self)
      case .patheventUpdateNodecreate:
        try ForwardOffset<Symbolic_PathEvent_Update_NodeCreate>.verify(&verifier, at: pos, of: Symbolic_PathEvent_Update_NodeCreate.self)
      case .patheventUpdateNodedelete:
        try ForwardOffset<Symbolic_PathEvent_Update_NodeDelete>.verify(&verifier, at: pos, of: Symbolic_PathEvent_Update_NodeDelete.self)
      case .patheventUpdateNodeupdate:
        try ForwardOffset<Symbolic_PathEvent_Update_NodeUpdate>.verify(&verifier, at: pos, of: Symbolic_PathEvent_Update_NodeUpdate.self)
      }
    })
    _v.finish()
  }
}

public struct Symbolic_PathEvent_Update_Move: FlatBufferObject, Verifiable {

  static func validateVersion() { FlatBuffersVersion_24_3_25() }
  public var __buffer: ByteBuffer! { return _accessor.bb }
  private var _accessor: Table

  private init(_ t: Table) { _accessor = t }
  public init(_ bb: ByteBuffer, o: Int32) { _accessor = Table(bb: bb, position: o) }

  private enum VTOFFSET: VOffset {
    case prevNodeId = 4
    case nodeId = 6
    case node = 8
    var v: Int32 { Int32(self.rawValue) }
    var p: VOffset { self.rawValue }
  }

  public var prevNodeId: Symbolic_UUID? { let o = _accessor.offset(VTOFFSET.prevNodeId.v); return o == 0 ? nil : Symbolic_UUID(_accessor.bb, o: _accessor.indirect(o + _accessor.postion)) }
  public var nodeId: Symbolic_UUID? { let o = _accessor.offset(VTOFFSET.nodeId.v); return o == 0 ? nil : Symbolic_UUID(_accessor.bb, o: _accessor.indirect(o + _accessor.postion)) }
  public var node: Symbolic_PathNode? { let o = _accessor.offset(VTOFFSET.node.v); return o == 0 ? nil : Symbolic_PathNode(_accessor.bb, o: _accessor.indirect(o + _accessor.postion)) }
  public static func startPathEvent_Update_Move(_ fbb: inout FlatBufferBuilder) -> UOffset { fbb.startTable(with: 3) }
  public static func add(prevNodeId: Offset, _ fbb: inout FlatBufferBuilder) { fbb.add(offset: prevNodeId, at: VTOFFSET.prevNodeId.p) }
  public static func add(nodeId: Offset, _ fbb: inout FlatBufferBuilder) { fbb.add(offset: nodeId, at: VTOFFSET.nodeId.p) }
  public static func add(node: Offset, _ fbb: inout FlatBufferBuilder) { fbb.add(offset: node, at: VTOFFSET.node.p) }
  public static func endPathEvent_Update_Move(_ fbb: inout FlatBufferBuilder, start: UOffset) -> Offset { let end = Offset(offset: fbb.endTable(at: start)); return end }
  public static func createPathEvent_Update_Move(
    _ fbb: inout FlatBufferBuilder,
    prevNodeIdOffset prevNodeId: Offset = Offset(),
    nodeIdOffset nodeId: Offset = Offset(),
    nodeOffset node: Offset = Offset()
  ) -> Offset {
    let __start = Symbolic_PathEvent_Update_Move.startPathEvent_Update_Move(&fbb)
    Symbolic_PathEvent_Update_Move.add(prevNodeId: prevNodeId, &fbb)
    Symbolic_PathEvent_Update_Move.add(nodeId: nodeId, &fbb)
    Symbolic_PathEvent_Update_Move.add(node: node, &fbb)
    return Symbolic_PathEvent_Update_Move.endPathEvent_Update_Move(&fbb, start: __start)
  }

  public static func verify<T>(_ verifier: inout Verifier, at position: Int, of type: T.Type) throws where T: Verifiable {
    var _v = try verifier.visitTable(at: position)
    try _v.visit(field: VTOFFSET.prevNodeId.p, fieldName: "prevNodeId", required: false, type: ForwardOffset<Symbolic_UUID>.self)
    try _v.visit(field: VTOFFSET.nodeId.p, fieldName: "nodeId", required: false, type: ForwardOffset<Symbolic_UUID>.self)
    try _v.visit(field: VTOFFSET.node.p, fieldName: "node", required: false, type: ForwardOffset<Symbolic_PathNode>.self)
    _v.finish()
  }
}

public struct Symbolic_PathEvent_Update_NodeCreate: FlatBufferObject, Verifiable {

  static func validateVersion() { FlatBuffersVersion_24_3_25() }
  public var __buffer: ByteBuffer! { return _accessor.bb }
  private var _accessor: Table

  private init(_ t: Table) { _accessor = t }
  public init(_ bb: ByteBuffer, o: Int32) { _accessor = Table(bb: bb, position: o) }

  private enum VTOFFSET: VOffset {
    case prevNodeId = 4
    case nodeId = 6
    case node = 8
    var v: Int32 { Int32(self.rawValue) }
    var p: VOffset { self.rawValue }
  }

  public var prevNodeId: Symbolic_UUID? { let o = _accessor.offset(VTOFFSET.prevNodeId.v); return o == 0 ? nil : Symbolic_UUID(_accessor.bb, o: _accessor.indirect(o + _accessor.postion)) }
  public var nodeId: Symbolic_UUID? { let o = _accessor.offset(VTOFFSET.nodeId.v); return o == 0 ? nil : Symbolic_UUID(_accessor.bb, o: _accessor.indirect(o + _accessor.postion)) }
  public var node: Symbolic_PathNode? { let o = _accessor.offset(VTOFFSET.node.v); return o == 0 ? nil : Symbolic_PathNode(_accessor.bb, o: _accessor.indirect(o + _accessor.postion)) }
  public static func startPathEvent_Update_NodeCreate(_ fbb: inout FlatBufferBuilder) -> UOffset { fbb.startTable(with: 3) }
  public static func add(prevNodeId: Offset, _ fbb: inout FlatBufferBuilder) { fbb.add(offset: prevNodeId, at: VTOFFSET.prevNodeId.p) }
  public static func add(nodeId: Offset, _ fbb: inout FlatBufferBuilder) { fbb.add(offset: nodeId, at: VTOFFSET.nodeId.p) }
  public static func add(node: Offset, _ fbb: inout FlatBufferBuilder) { fbb.add(offset: node, at: VTOFFSET.node.p) }
  public static func endPathEvent_Update_NodeCreate(_ fbb: inout FlatBufferBuilder, start: UOffset) -> Offset { let end = Offset(offset: fbb.endTable(at: start)); return end }
  public static func createPathEvent_Update_NodeCreate(
    _ fbb: inout FlatBufferBuilder,
    prevNodeIdOffset prevNodeId: Offset = Offset(),
    nodeIdOffset nodeId: Offset = Offset(),
    nodeOffset node: Offset = Offset()
  ) -> Offset {
    let __start = Symbolic_PathEvent_Update_NodeCreate.startPathEvent_Update_NodeCreate(&fbb)
    Symbolic_PathEvent_Update_NodeCreate.add(prevNodeId: prevNodeId, &fbb)
    Symbolic_PathEvent_Update_NodeCreate.add(nodeId: nodeId, &fbb)
    Symbolic_PathEvent_Update_NodeCreate.add(node: node, &fbb)
    return Symbolic_PathEvent_Update_NodeCreate.endPathEvent_Update_NodeCreate(&fbb, start: __start)
  }

  public static func verify<T>(_ verifier: inout Verifier, at position: Int, of type: T.Type) throws where T: Verifiable {
    var _v = try verifier.visitTable(at: position)
    try _v.visit(field: VTOFFSET.prevNodeId.p, fieldName: "prevNodeId", required: false, type: ForwardOffset<Symbolic_UUID>.self)
    try _v.visit(field: VTOFFSET.nodeId.p, fieldName: "nodeId", required: false, type: ForwardOffset<Symbolic_UUID>.self)
    try _v.visit(field: VTOFFSET.node.p, fieldName: "node", required: false, type: ForwardOffset<Symbolic_PathNode>.self)
    _v.finish()
  }
}

public struct Symbolic_PathEvent_Update_NodeDelete: FlatBufferObject, Verifiable {

  static func validateVersion() { FlatBuffersVersion_24_3_25() }
  public var __buffer: ByteBuffer! { return _accessor.bb }
  private var _accessor: Table

  private init(_ t: Table) { _accessor = t }
  public init(_ bb: ByteBuffer, o: Int32) { _accessor = Table(bb: bb, position: o) }

  private enum VTOFFSET: VOffset {
    case nodeId = 4
    var v: Int32 { Int32(self.rawValue) }
    var p: VOffset { self.rawValue }
  }

  public var nodeId: Symbolic_UUID? { let o = _accessor.offset(VTOFFSET.nodeId.v); return o == 0 ? nil : Symbolic_UUID(_accessor.bb, o: _accessor.indirect(o + _accessor.postion)) }
  public static func startPathEvent_Update_NodeDelete(_ fbb: inout FlatBufferBuilder) -> UOffset { fbb.startTable(with: 1) }
  public static func add(nodeId: Offset, _ fbb: inout FlatBufferBuilder) { fbb.add(offset: nodeId, at: VTOFFSET.nodeId.p) }
  public static func endPathEvent_Update_NodeDelete(_ fbb: inout FlatBufferBuilder, start: UOffset) -> Offset { let end = Offset(offset: fbb.endTable(at: start)); return end }
  public static func createPathEvent_Update_NodeDelete(
    _ fbb: inout FlatBufferBuilder,
    nodeIdOffset nodeId: Offset = Offset()
  ) -> Offset {
    let __start = Symbolic_PathEvent_Update_NodeDelete.startPathEvent_Update_NodeDelete(&fbb)
    Symbolic_PathEvent_Update_NodeDelete.add(nodeId: nodeId, &fbb)
    return Symbolic_PathEvent_Update_NodeDelete.endPathEvent_Update_NodeDelete(&fbb, start: __start)
  }

  public static func verify<T>(_ verifier: inout Verifier, at position: Int, of type: T.Type) throws where T: Verifiable {
    var _v = try verifier.visitTable(at: position)
    try _v.visit(field: VTOFFSET.nodeId.p, fieldName: "nodeId", required: false, type: ForwardOffset<Symbolic_UUID>.self)
    _v.finish()
  }
}

public struct Symbolic_PathEvent_Update_NodeUpdate: FlatBufferObject, Verifiable {

  static func validateVersion() { FlatBuffersVersion_24_3_25() }
  public var __buffer: ByteBuffer! { return _accessor.bb }
  private var _accessor: Table

  private init(_ t: Table) { _accessor = t }
  public init(_ bb: ByteBuffer, o: Int32) { _accessor = Table(bb: bb, position: o) }

  private enum VTOFFSET: VOffset {
    case nodeId = 4
    case node = 6
    var v: Int32 { Int32(self.rawValue) }
    var p: VOffset { self.rawValue }
  }

  public var nodeId: Symbolic_UUID? { let o = _accessor.offset(VTOFFSET.nodeId.v); return o == 0 ? nil : Symbolic_UUID(_accessor.bb, o: _accessor.indirect(o + _accessor.postion)) }
  public var node: Symbolic_PathNode? { let o = _accessor.offset(VTOFFSET.node.v); return o == 0 ? nil : Symbolic_PathNode(_accessor.bb, o: _accessor.indirect(o + _accessor.postion)) }
  public static func startPathEvent_Update_NodeUpdate(_ fbb: inout FlatBufferBuilder) -> UOffset { fbb.startTable(with: 2) }
  public static func add(nodeId: Offset, _ fbb: inout FlatBufferBuilder) { fbb.add(offset: nodeId, at: VTOFFSET.nodeId.p) }
  public static func add(node: Offset, _ fbb: inout FlatBufferBuilder) { fbb.add(offset: node, at: VTOFFSET.node.p) }
  public static func endPathEvent_Update_NodeUpdate(_ fbb: inout FlatBufferBuilder, start: UOffset) -> Offset { let end = Offset(offset: fbb.endTable(at: start)); return end }
  public static func createPathEvent_Update_NodeUpdate(
    _ fbb: inout FlatBufferBuilder,
    nodeIdOffset nodeId: Offset = Offset(),
    nodeOffset node: Offset = Offset()
  ) -> Offset {
    let __start = Symbolic_PathEvent_Update_NodeUpdate.startPathEvent_Update_NodeUpdate(&fbb)
    Symbolic_PathEvent_Update_NodeUpdate.add(nodeId: nodeId, &fbb)
    Symbolic_PathEvent_Update_NodeUpdate.add(node: node, &fbb)
    return Symbolic_PathEvent_Update_NodeUpdate.endPathEvent_Update_NodeUpdate(&fbb, start: __start)
  }

  public static func verify<T>(_ verifier: inout Verifier, at position: Int, of type: T.Type) throws where T: Verifiable {
    var _v = try verifier.visitTable(at: position)
    try _v.visit(field: VTOFFSET.nodeId.p, fieldName: "nodeId", required: false, type: ForwardOffset<Symbolic_UUID>.self)
    try _v.visit(field: VTOFFSET.node.p, fieldName: "node", required: false, type: ForwardOffset<Symbolic_PathNode>.self)
    _v.finish()
  }
}

