import Foundation
import SceneKit

/**
 * Register objects to be synchronized across the network. Registered items have an identifier
 * and a state.
 */

protocol ReadRegistrar {
    func register(_ node: SCNNode, id: UInt16)
}

class ReadStateSynchronizer<I: InputInterpreter>: ReadRegistrar {
    var registry = Set<ReadRegistration>()
    var node2registered = [SCNNode:ReadRegistration]()
    var id2node = [UInt16:SCNNode]()
    var referenceNode: SCNNode?
    var inputWindowBuffer = InputWindowBuffer(capacity: 1024)
    let inputReadQueue = InputReadQueue(capacity: Packet.maxInputsPerPacket)
    let jitterBuffer = JitterBuffer(capacity: 1024)

    func apply(packet: Packet, to scene: SCNScene, with inputInterpreter: I) {
        let inputs = inputReadQueue.filter(inputs: packet.inputs)
        for input in inputs {
            inputInterpreter.apply(datas: input.underlying, with: self)
        }
        for state in packet.updates {
            if let node = id2node[state.id] {
                node.update(to: state, with: referenceNode ?? SCNNode())
            } else {
                inputInterpreter.nodeMissing(with: state)
            }
        }
    }

    func register(_ node: SCNNode, id: UInt16) {
        if node2registered[node] != nil { fatalError("already registered") }

        let registered = ReadRegistration(id: id, value: node)
        node2registered[node] = registered
        id2node[id] = node

        registry.insert(registered)
    }
}

class WriteStateSynchronizer {
    let serialQueue = DispatchQueue(label: "WriteStateSynchronizer")

    var registry = Set<WriteRegistration>()
    var node2registered = [SCNNode:WriteRegistration]()
    var id2node = [UInt16:SCNNode]()
    var counter: UInt16 = 0
    let priorityAccumulator = PriorityAccumulator()
    var referenceNode: SCNNode?
    var inputWindowBuffer = InputWindowBuffer(capacity: 1024)
    let inputWriteQueue = InputWriteQueue()

    func packet(at sequence: Int) -> Packet {
        return serialQueue.sync {
            let sequenceTruncated = UInt16(sequence % Int(UInt16.max))

            priorityAccumulator.update(registry: registry)
            let inThisPacket = priorityAccumulator.top(Packet.maxStateUpdatesPerPacket, in: registry)
            let updates = inThisPacket.map { $0.state(with: referenceNode ?? SCNNode()) }

            inputWriteQueue.write(to: inputWindowBuffer, at: sequenceTruncated)
            let inputs = inputWindowBuffer.top(Packet.maxInputsPerPacket, at: sequenceTruncated)
            return Packet(sequence: sequenceTruncated, updates: updates, inputs: inputs)
        }
    }

    func input(_ dataConvertible: DataConvertible) {

        inputWriteQueue.push(dataConvertible.data)
    }
    
    func register(_ node: SCNNode, priority: Float, registrationCallback: @escaping (WriteRegistration) -> ()) {
        register(node, priorityCallback: { () in
            return priority
        }, registrationCallback: registrationCallback)
    }

    func register(_ node: SCNNode, priorityCallback: @escaping () -> Float, registrationCallback: @escaping (WriteRegistration) -> ()) {
        serialQueue.async {
            if self.node2registered[node] != nil { return }

            self.counter += 1
            assert(self.counter < .max)
            let registered = WriteRegistration(id: self.counter, value: node, priorityCallback: priorityCallback)
            self.node2registered[node] = registered
            self.id2node[self.counter] = node

            registrationCallback(registered)
            self.registry.insert(registered)
        }
    }
}

struct WriteRegistration: Hashable, Equatable {
    let id: UInt16
    let value: SCNNode
    let priorityCallback: () -> Float

    var hashValue: Int {
        return Int(id)
    }

    var priority: Float {
        return priorityCallback()
    }

    static func ==(lhs: WriteRegistration, rhs: WriteRegistration) -> Bool {
        return lhs.id == rhs.id
    }

    func state(with referenceNode: SCNNode) -> NodeState {
        let transform = referenceNode.simdConvertTransform(value.presentation.simdWorldTransform, from: nil)
        let position = float3(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
        let orientation = simd_quaternion(transform).vector

        if let physicsBody = value.physicsBody {
            if !physicsBody.isResting &&
                !(float3(physicsBody.velocity) == float3(0,0,0) &&
                    float4(physicsBody.angularVelocity) == float4(0,0,0,0)) {
                return FullNodeState(id: id, position: position, orientation: orientation, linearVelocity: float3(physicsBody.velocity), angularVelocity: float4(physicsBody.angularVelocity))
            }
        }

        return CompactNodeState(id: id, position: position, orientation: orientation)
    }
}

struct ReadRegistration: Hashable, Equatable {
    let id: UInt16
    let value: SCNNode

    var hashValue: Int {
        return Int(id)
    }

    static func ==(lhs: ReadRegistration, rhs: ReadRegistration) -> Bool {
        return lhs.id == rhs.id
    }
}
