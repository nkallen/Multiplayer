import Foundation
import SceneKit

fileprivate var node2registered = [SCNNode:Registered]()
fileprivate var id2node = [Int16:SCNNode]()
fileprivate var counter: Int16 = 0
fileprivate var registry = Set<Registered>()
fileprivate let priorityAccumulator = PriorityAccumulator()
fileprivate var sequence: Int16 = 0

struct Registered: Hashable, Equatable {
    static var registered: Set<Registered> {
        return registry
    }

    let id: Int16
    let value: SCNNode

    var hashValue: Int {
        return Int(id)
    }

    static func ==(lhs: Registered, rhs: Registered) -> Bool {
        return lhs.id == rhs.id
    }

    var state: NodeState {
        if let physicsBody = value.physicsBody {
            if !physicsBody.isResting &&
                !(float3(physicsBody.velocity) == float3(0,0,0) &&
                        float4(physicsBody.angularVelocity) == float4(0,0,0,0)) {
                return FullNodeState(id: id, position: value.presentation.simdPosition, eulerAngles: value.presentation.simdEulerAngles, linearVelocity: float3(physicsBody.velocity), angularVelocity: float4(physicsBody.angularVelocity))
            }
        }

        return CompactNodeState(id: id, position: value.presentation.simdPosition, eulerAngles: value.presentation.simdEulerAngles)
    }
}

protocol Registerable {
    func register() -> Registered
}

extension SCNNode: Registerable {
    func register() -> Registered {
        if let registered = node2registered[self] { return registered }

        counter += 1
        assert(counter < .max)
        let registered = Registered(id: counter, value: self)
        node2registered[self] = registered
        id2node[counter] = self

        registry.insert(registered)
        return registered
    }

    func update(to state: NodeState) {
        simdPosition = state.position
        simdEulerAngles = state.eulerAngles
        if let physicsBody = physicsBody {
            physicsBody.velocity = SCNVector3(state.linearVelocity)
            physicsBody.angularVelocity = SCNVector4(state.angularVelocity)
            physicsBody.resetTransform()
        }
    }
}

extension SCNScene {
    func packet(sequence: Int) -> Packet {
        let sequence = Int16(sequence % Int(Int16.max))
        priorityAccumulator.update()
        return Packet(sequence: sequence, updates: priorityAccumulator.top(Packet.maxStateUpdatesPerPacket).map { $0.state })
    }

    func apply(packet: Packet) {
        for update in packet.updates {
            if let node = id2node[update.id] {
                node.update(to: update)
            } else {
                let box = SCNBox(width: 1, height: 1, length: 1, chamferRadius: 0)
                box.firstMaterial = SCNMaterial.material(withDiffuse: UIColor.blue.withAlphaComponent(0.5))
                let node = SCNNode(geometry: box)
                node.simdPosition = float3(0, 10, 0)
                node.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
                node.register()
                rootNode.addChildNode(node)
                node.update(to: update)
            }
        }
    }
}

protocol NodeState: DataConvertible {
    var id: Int16 { get }
    var position: float3 { get }
    var eulerAngles: float3 { get }
    var linearVelocity: float3 { get }
    var angularVelocity: float4 { get }
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
    var angularVelocity: float4 { return float4(0,0,0,0) }

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
    let angularVelocity: float4

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
    let updatesCompact: [CompactNodeState]
    let updatesFull: [FullNodeState]

    init(sequence: Int16, updates: [NodeState]) {
        var updatesCompact = [CompactNodeState]()
        var updatesFull = [FullNodeState]()
        for update in updates {
            switch update {
            case let update as CompactNodeState:
                updatesCompact.append(update)
            case let update as FullNodeState:
                updatesFull.append(update)
            default: ()
            }
        }
        self.sequence = sequence
        self.updatesCompact = updatesCompact
        self.updatesFull = updatesFull
    }

    var updates: [NodeState] {
        return (updatesCompact as [NodeState]) + (updatesFull as [NodeState])
    }

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
        for registered in registry {
            if let prioritized = registered.value as? HasPriority {
                let id = registered.id
                priorities[Int(id)] = priorities[Int(id)] + prioritized.intrinsicPriority
            }
        }
    }

    func top(_ count: Int) -> [Registered] {
        let sorted = registry.sorted { (item1, item2) -> Bool in
            let id1 = item1.id
            let id2 = item2.id
            return priorities[Int(id1)] > priorities[Int(id2)]
        }
        var result = [Registered]()
        for registered in sorted[0..<min(count, sorted.count)] {
            let id = registered.id
            priorities[Int(id)] = 0
            result.append(registered)
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

    var lastReceived: Int16 = -1
    var count = 0

    init(capacity: Int, minDelay: Int = 5) {
        assert(minDelay >= 0)

        self.buffer = [Packet?](repeating: nil, count: capacity)
        self.minDelay = minDelay
    }

    func push(_ packet: Packet) {
        buffer[Int(packet.sequence) % buffer.count] = packet
        lastReceived = max(packet.sequence, lastReceived)
    }

    subscript(sequence: Int) -> Packet? {
        let sequence = sequence - minDelay
        guard sequence >= 0 else { return nil }
        guard sequence <= lastReceived else { return nil }

        return buffer[sequence % buffer.count]
    }

}

protocol DataConvertible {
    init?(dataWrapper: DataWrapper)
    var data: Data { get }
}

extension DataConvertible {
    init?(dataWrapper: DataWrapper) {
        guard dataWrapper.count >= MemoryLayout<Self>.size else { return nil }
        let data = dataWrapper.read(MemoryLayout<Self>.size)
        self = data.withUnsafeBytes { $0.pointee }
    }

    var data: Data {
        var value = self
        return Data(buffer: UnsafeBufferPointer(start: &value, count: 1))
    }
}

extension UInt8: DataConvertible {}
extension Int16: DataConvertible {}
extension Int: DataConvertible {}
extension Float: DataConvertible {}
extension Double: DataConvertible {}
extension float3: DataConvertible {}
extension float4: DataConvertible {}
extension Array: DataConvertible {
    var data: Data {
        var values = self
        return Data(buffer: UnsafeBufferPointer(start: &values, count: count))
    }

    init?(dataWrapper: DataWrapper, count: Int) {
        guard dataWrapper.count >= MemoryLayout<Iterator.Element>.stride * count else { return nil }
        self.init(data: dataWrapper.read(MemoryLayout<Iterator.Element>.stride * count))
    }

    init?(data: Data) {
        self = data.withUnsafeBytes {
            [Iterator.Element](UnsafeBufferPointer(start: $0, count: data.count/MemoryLayout<Iterator.Element>.stride))
        }
    }
}
extension Packet: DataConvertible {
    static let minimumSizeInBytes = 4

    init?(dataWrapper: DataWrapper) {
        guard dataWrapper.count >= Packet.minimumSizeInBytes else { return nil }

        guard let sequence = Int16(dataWrapper: dataWrapper) else { return nil}
        guard let compactCount = UInt8(dataWrapper: dataWrapper) else { return nil }
        guard let compactUpdates = [CompactNodeState](dataWrapper: dataWrapper, count: Int(compactCount)) else { return nil }
        guard let fullCount = UInt8(dataWrapper: dataWrapper) else { return nil }
        guard let fullUpdates = [FullNodeState](dataWrapper: dataWrapper, count: Int(fullCount)) else { return nil }

        self.sequence = sequence
        self.updatesCompact = compactUpdates
        self.updatesFull = fullUpdates
    }

    var data: Data {
        let mutableData = NSMutableData()
        mutableData.append(sequence.data)
        mutableData.append(UInt8(updatesCompact.count).data)
        mutableData.append(updatesCompact.data)
        mutableData.append(UInt8(updatesFull.count).data)
        mutableData.append(updatesFull.data)
        return mutableData as Data
    }
}

extension FullNodeState: DataConvertible {
    static let sizeInBytes = 66

    init?(dataWrapper: DataWrapper) {
        guard dataWrapper.count == FullNodeState.sizeInBytes else { return nil }

        guard let id = Int16(dataWrapper: dataWrapper) else { return nil }
        guard let position = float3(dataWrapper: dataWrapper) else { return nil }
        guard let eulerAngles = float3(dataWrapper: dataWrapper) else { return nil }
        guard let linearVelocity = float3(dataWrapper: dataWrapper) else { return nil }
        guard let angularVelocity = float4(dataWrapper: dataWrapper) else { return nil }

        self.id = id
        self.position = position
        self.eulerAngles = eulerAngles
        self.linearVelocity = linearVelocity
        self.angularVelocity = angularVelocity
    }

    var data: Data {
        let mutableData = NSMutableData()
        mutableData.append(id.data)
        mutableData.append(position.data)
        mutableData.append(eulerAngles.data)
        mutableData.append(linearVelocity.data)
        mutableData.append(angularVelocity.data)
        return mutableData as Data
    }
}

extension CompactNodeState: DataConvertible {
    static let sizeInBytes = 34

    init?(dataWrapper: DataWrapper) {
        guard dataWrapper.count >= CompactNodeState.sizeInBytes else { return nil }

        guard let id = Int16(dataWrapper: dataWrapper) else { return nil }
        guard let position = float3(dataWrapper: dataWrapper) else { return nil }
        guard let eulerAngles = float3(dataWrapper: dataWrapper) else { return nil }

        self.id = id
        self.position = position
        self.eulerAngles = eulerAngles
    }
    
    var data: Data {
        let mutableData = NSMutableData()
        mutableData.append(id.data)
        mutableData.append(position.data)
        mutableData.append(eulerAngles.data)
        return mutableData as Data
    }
}

class DataWrapper {
    let underlying: Data
    var cursor = 0

    init(_ underlying: Data) {
        self.underlying = underlying
    }

    func read(_ count: Int) -> Data {
        let result = underlying.subdata(in: cursor..<cursor+count)
        cursor += count
        return result
    }

    var count: Int {
        return underlying.count - cursor
    }
}
