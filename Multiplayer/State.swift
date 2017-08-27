import Foundation
import SceneKit

protocol NodeState {
    var id: Int { get }
    var position: float3 { get }
    var orientation: float4 { get }
    var linearVelocity: float3 { get }
    var angularVelocity: float3 { get }
}

extension NodeState {
    func isEqual(to rhs: NodeState) -> Bool {
        let lhs = self
        return lhs.id == rhs.id &&
            lhs.position == rhs.position &&
            lhs.orientation == rhs.orientation &&
            lhs.linearVelocity == rhs.linearVelocity &&
            lhs.angularVelocity == rhs.angularVelocity
    }
}

func ==(lhs: [NodeState], rhs: [NodeState]) -> Bool {
    guard lhs.count == rhs.count else { return false }

    for i in 0..<lhs.count {
        let leftItem: NodeState = lhs[i], rightItem: NodeState = rhs[i]
        if !leftItem.isEqual(to: rightItem) {
            return false
        }
    }
    return true
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
            lhs.orientation == rhs.orientation &&
            lhs.linearVelocity == rhs.linearVelocity &&
            lhs.angularVelocity == rhs.angularVelocity
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

struct Packet: Equatable, Comparable {
    static let maxInputsPerPacket = 32
    static let maxStateUpdatesPerPacket = 64

    let sequence: Int16
    let updates: [NodeState]

    static func ==(lhs: Packet, rhs: Packet) -> Bool {
        return lhs.sequence == rhs.sequence &&
            lhs.updates == rhs.updates
    }

    static func <(lhs: Packet, rhs: Packet) -> Bool {
        return lhs.sequence < rhs.sequence
    }
}

class PriorityAccumulator {
    var all = [HasPriority]()

    var priorities = [HasPriority:Float]()

    func update() {
        for item in all {
            priorities[item] = (priorities[item] ?? 0) + item.intrinsicPriority
        }
    }

    func top(_ count: Int) -> [HasPriority] {
        let sorted = priorities.sorted { (np1, np2) -> Bool in
            let (_, priority1) = np1
            let (_, priority2) = np2

            return priority1 > priority2
        }
        var result = [HasPriority]()
        for (hasPriority, _) in sorted[0..<count] {
            priorities[hasPriority] = 0
            result.append(hasPriority)
        }
        return result
    }
}

struct HasPriority: Hashable {
    var hashValue: Int { return node.hashValue }

    static func ==(lhs: HasPriority, rhs: HasPriority) -> Bool {
        return lhs.node == rhs.node
    }

    let intrinsicPriority: Float
    let node: SCNNode
}

class JitterBuffer {
    var buffer: [Packet?]
    let minDelay: Int

    var lastSeen: Int16 = -1
    var count = 0

    init(capacity: Int, minDelay: Int = 5) {
        assert(minDelay >= 0)

        self.buffer = [Packet?](repeating: nil, count: capacity)
        self.minDelay = minDelay
    }

    func push(_ packet: Packet) {
        buffer[Int(packet.sequence) % buffer.count] = packet
        lastSeen = max(packet.sequence, lastSeen)
    }

    subscript(sequence: Int) -> Packet? {
        let sequence = sequence - minDelay
        guard sequence >= 0 else { return nil }

        return buffer[sequence]
    }

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
extension Packet: DataConvertible {}
