import Foundation
import SceneKit

/**
 * Register objects to be synchronized across the network. Registered items have an identifier
 * and a state.
 */

class StateSynchronizer {
    var registry = Set<Registered>()
    var node2registered = [SCNNode:Registered]()
    var id2node = [Int16:SCNNode]()
    var counter: Int16 = 0
    let priorityAccumulator = PriorityAccumulator()
    let jitterBuffer = JitterBuffer(capacity: 1024)

    func packet(at sequence: Int) -> Packet {
        let sequence = Int16(sequence % Int(Int16.max))
        priorityAccumulator.update(registry: registry)
        return Packet(sequence: sequence, updates: priorityAccumulator.top(Packet.maxStateUpdatesPerPacket, in: registry).map { $0.state })
    }

    func apply(packet: Packet, to scene: SCNScene) {
        for update in packet.updates {
            if let node = id2node[update.id] {
                node.update(to: update)
            } else {
                // This is temporary/a hack: if we observe an update to a node that doesn't exist,
                // create it.
                let node = createNodeOutOfThinAir(scene: scene)
                register(node)
                node.update(to: update)
            }
        }
    }

    func register(_ node: SCNNode) -> Registered {
        if let registered = node2registered[node] { return registered }

        counter += 1
        assert(counter < .max)
        let registered = Registered(id: counter, value: node)
        node2registered[node] = registered
        id2node[counter] = node

        registry.insert(registered)
        return registered
    }

    private func createNodeOutOfThinAir(scene: SCNScene) -> SCNNode {
        let box = SCNBox(width: 1, height: 1, length: 1, chamferRadius: 0)
        box.firstMaterial = SCNMaterial.material(withDiffuse: UIColor.blue.withAlphaComponent(0.5))
        let node = SCNNode(geometry: box)
        node.simdPosition = float3(0, 10, 0)
        node.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
        scene.rootNode.addChildNode(node)
        return node
    }
}

struct Registered: Hashable, Equatable {
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

