import Foundation
import SceneKit

/**
 * Register objects to be synchronized across the network. Registered items have an identifier
 * and a state.
 */

class StateSynchronizer {
    var registry = Set<Registered>()
    var node2registered = [SCNNode:Registered]()
    var id2node = [UInt16:SCNNode]()
    var counter: UInt16 = 0
    let priorityAccumulator = PriorityAccumulator()
    var referenceNode: SCNNode?
    var inputWindowBuffer = InputWindowBuffer(capacity: 1024)

    func register(_ node: SCNNode) -> Registered {
        return register(node, priority: 0)
    }

    func register(_ node: SCNNode, priority: Float) -> Registered {
        return register(node) { () in
            return priority
        }
    }

    func register(_ node: SCNNode, priorityCallback: @escaping () -> Float) -> Registered {
        if let registered = node2registered[node] { return registered }

        counter += 1
        assert(counter < .max)
        let registered = Registered(id: counter, value: node, priorityCallback: priorityCallback)
        node2registered[node] = registered
        id2node[counter] = node

        registry.insert(registered)
        return registered
    }

}

class ReadStateSynchronizer: StateSynchronizer {
    let inputReadQueue = InputReadQueue(capacity: Packet.maxInputsPerPacket)
    let jitterBuffer = JitterBuffer(capacity: 1024)

    func apply(packet: Packet, to scene: SCNScene, with inputInterpreter: InputInterpreter) {
        let inputs = inputReadQueue.filter(inputs: packet.inputs)
        for input in inputs {
            inputInterpreter.apply(input: input.underlying, from: self)
        }
        for state in packet.updates {
            if let node = id2node[state.id] {
                node.update(to: state, with: referenceNode ?? SCNNode())
            } else {
                inputInterpreter.nodeMissing(with: state)
            }
        }
    }
}

class WriteStateSynchronizer: StateSynchronizer {
    let inputWriteQueue = InputWriteQueue()

    func packet(at sequence: Int) -> Packet {
        let sequenceTruncated = UInt16(sequence % Int(UInt16.max))

        priorityAccumulator.update(registry: registry)
        let inThisPacket = priorityAccumulator.top(Packet.maxStateUpdatesPerPacket, in: registry)
        let updates = inThisPacket.map { $0.state(with: referenceNode ?? SCNNode()) }

        inputWriteQueue.write(to: inputWindowBuffer, at: sequenceTruncated)
        let inputs = inputWindowBuffer.top(Packet.maxInputsPerPacket, at: sequenceTruncated)
        return Packet(sequence: sequenceTruncated, updates: updates, inputs: inputs)
    }

    func input(_ dataConvertible: DataConvertible) {
        inputWriteQueue.push(dataConvertible.data)
    }
}

struct Registered: Hashable, Equatable {
    let id: UInt16
    let value: SCNNode
    let priorityCallback: () -> Float

    var hashValue: Int {
        return Int(id)
    }

    var priority: Float {
        return priorityCallback()
    }

    static func ==(lhs: Registered, rhs: Registered) -> Bool {
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

