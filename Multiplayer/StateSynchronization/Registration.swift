import Foundation
import SceneKit

/**
 * Register objects to be synchronized across the network. Registered items have an identifier
 * and a state.
 */

// TODO FIXME: Int16 -> UInt16; sep ReadStateSync from WriteStateSync

class StateSynchronizer {
    var registry = Set<Registered>()
    var node2registered = [SCNNode:Registered]()
    var id2node = [Int16:SCNNode]()
    var counter: Int16 = 0
    let priorityAccumulator = PriorityAccumulator()
    let jitterBuffer = JitterBuffer(capacity: 1024)
    var referenceNode: SCNNode?
    var inputWindowBuffer = InputWindowBuffer(capacity: 1024)
    let inputWriteQueue = InputWriteQueue()
    let inputReadQueue = InputReadQueue(capacity: Packet.maxInputsPerPacket)

    func packet(at sequence: Int) -> Packet {
        let sequenceTruncated = Int16(sequence % Int(Int16.max))

        priorityAccumulator.update(registry: registry)
        let inThisPacket = priorityAccumulator.top(Packet.maxStateUpdatesPerPacket, in: registry)
        let updates = inThisPacket.map { $0.state(with: referenceNode ?? SCNNode()) }

        inputWriteQueue.write(to: inputWindowBuffer, at: sequenceTruncated)
        let inputs = inputWindowBuffer.top(Packet.maxInputsPerPacket, at: sequenceTruncated)
        print("writing packet with", updates.count, inputs.count)
        return Packet(sequence: sequenceTruncated, updates: updates, inputs: inputs)
    }

    func apply(packet: Packet, to scene: SCNScene, with inputInterpreter: InputInterpreter) {
        print("reading packet with", packet.updates.count, packet.inputs.count)
        let inputs = inputReadQueue.filter(inputs: packet.inputs)
        print("after filtration", inputs.count)
        for input in inputs {
            inputInterpreter.apply(type: input.type, id: input.nodeId, from: self)
        }
        for state in packet.updates {
            if let node = id2node[state.id] {
                node.update(to: state, with: referenceNode ?? SCNNode())
            } else {
                print("node", state.id, "doesn't exist yet")
            }
        }
    }

    func register(_ node: SCNNode, priority: Float) -> Registered {
        return register(node) { () in
            return priority
        }
    }

    func register(_ node: SCNNode, priorityCallback: @escaping () -> Float) -> Registered {
        if let registered = node2registered[node] { return registered }

        counter += 1
        print("registering with counter", counter)
        assert(counter < .max)
        let registered = Registered(id: counter, value: node, priorityCallback: priorityCallback)
        node2registered[node] = registered
        id2node[counter] = node

        registry.insert(registered)
        return registered
    }

    func event(type: UInt8, id: Int16) {
        inputWriteQueue.push(type: type, id: id)
    }

    private func createNodeOutOfThinAir(scene: SCNScene) -> SCNNode {
        let node = createAxesNode(quiverLength: 0.1, quiverThickness: 1.0)
//        let fire = SCNScene(named: "scene.scn", inDirectory: "Models.scnassets/Fire")!.rootNode.childNodes.first!
        scene.rootNode.addChildNode(node)
        return node
    }
}

struct Registered: Hashable, Equatable {
    let id: Int16
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
//        print("in state:", value.presentation.simdWorldPosition, value.presentation.simdWorldOrientation)

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

