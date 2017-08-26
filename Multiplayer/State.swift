import Foundation
import SceneKit

protocol NodeState {
    var id: Int { get }
    var position: float3 { get }
    var orientation: float4 { get }
    var linearVelocity: float3 { get }
    var angularVelocity: float3 { get }
}

struct CompactNodeState: NodeState, Equatable {
    let id: Int
    let position: float3
    let orientation: float4
    var linearVelocity: float3 { return float3(0,0,0) }
    var angularVelocity: float3 { return float3(0,0,0) }

    static func ==(lhs: CompactNodeState, rhs: CompactNodeState) -> Bool {
        return lhs.id == rhs.id &&
            lhs.position == rhs.position &&
            lhs.orientation == rhs.orientation
    }
}

struct FullNodeState: NodeState, Equatable {
    let id: Int
    let position: float3
    let orientation: float4
    let linearVelocity: float3
    let angularVelocity: float3

    static func ==(lhs: FullNodeState, rhs: FullNodeState) -> Bool {
        return lhs.id == rhs.id &&
            lhs.position == rhs.position &&
            lhs.orientation == rhs.orientation &&
            lhs.linearVelocity == rhs.linearVelocity &&
            lhs.angularVelocity == rhs.angularVelocity
    }
}

struct Packet {
    static let maxInputsPerPacket = 32
    static let maxStateUpdatesPerPacket = 64

    let sequence: Int
    let updates = [FullNodeState]()
}

class PriorityAccumulator {
    var priorities = [SCNNode:Float]()
}

class JitterBuffer {
    let buffer = [Packet]()
}

protocol DataConvertible {
    init?(data: Data)
    var data: Data { get }
}

extension DataConvertible {
    init?(data: Data) {
        guard data.count == MemoryLayout<Self>.size else { return nil }
        self = data.withUnsafeBytes { $0.pointee }
    }

    var data: Data {
        var value = self
        return Data(buffer: UnsafeBufferPointer(start: &value, count: 1))
    }
}

extension Int: DataConvertible {}
extension Float: DataConvertible {}
extension Double: DataConvertible {}
extension float3: DataConvertible {}
extension float4: DataConvertible {}
extension FullNodeState: DataConvertible {}
extension CompactNodeState: DataConvertible {}

