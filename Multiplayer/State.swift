import Foundation
import SceneKit

fileprivate var node2id = [SCNNode:Int16]()
fileprivate var counter: Int16 = 0
fileprivate var registry = Set<SCNNode>()

protocol Registered {
    var id: Int16? { get }
    func register()
}

extension SCNNode: Registered {
    static var registered: Set<SCNNode> {
        return registry
    }

    var id: Int16? {
        return node2id[self]
    }

    func register() {
        guard !registry.contains(self) else { return }

        counter += 1
        assert(counter < .max)
        node2id[self] = counter

        registry.insert(self)
    }

    var state: NodeState? {
        if let id = id {
            return CompactNodeState(id: id, position: simdPosition, eulerAngles: simdEulerAngles)
        }
        return nil
    }
}

extension SCNScene {
    var packet: Packet {
        return Packet(sequence: 0, updates: [])
    }
}

protocol NodeState {
    var id: Int16 { get }
    var position: float3 { get }
    var eulerAngles: float3 { get }
    var linearVelocity: float3 { get }
    var angularVelocity: float3 { get }
}

extension NodeState {
    func isEqual(to rhs: NodeState) -> Bool {
        let lhs = self
        return lhs.id == rhs.id &&
            lhs.position == rhs.position &&
            lhs.eulerAngles == rhs.eulerAngles &&
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
    let id: Int16
    let position: float3
    let eulerAngles: float3
    var linearVelocity: float3 { return float3(0,0,0) }
    var angularVelocity: float3 { return float3(0,0,0) }

    static func ==(lhs: CompactNodeState, rhs: CompactNodeState) -> Bool {
        return lhs.id == rhs.id &&
            lhs.position == rhs.position &&
            lhs.eulerAngles == rhs.eulerAngles &&
            lhs.linearVelocity == rhs.linearVelocity &&
            lhs.angularVelocity == rhs.angularVelocity
    }
}

struct FullNodeState: NodeState, Equatable {
    let id: Int16
    let position: float3
    let eulerAngles: float3
    let linearVelocity: float3
    let angularVelocity: float3

    static func ==(lhs: FullNodeState, rhs: FullNodeState) -> Bool {
        return lhs.id == rhs.id &&
            lhs.position == rhs.position &&
            lhs.eulerAngles == rhs.eulerAngles &&
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
    var priorities = [Float](repeating: 0, count: Int(Int16.max))

    func update() {
        for item in registry {
            if let registered = item as? Registered,
                let id = registered.id,
                let prioritized = item as? HasPriority {
                let original = priorities[Int(id)]
                priorities[Int(id)] = priorities[Int(id)] + prioritized.intrinsicPriority
            }
        }
    }

    func top(_ count: Int) -> [SCNNode] {
        let sorted = registry.sorted { (item1, item2) -> Bool in
            if let id1 = item1.id, let id2 = item2.id {
                return priorities[Int(id1)] > priorities[Int(id2)]
            }
            return false
        }
        var result = [SCNNode]()
        for node in sorted[0..<count] {
            if let id = node.id {
                priorities[Int(id)] = 0
                result.append(node)
            }
        }
        return result
    }
}

protocol HasPriority {
    var intrinsicPriority: Float { get }
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
