import Foundation
import SceneKit

/**
 * Register objects to be synchronized across the network. Registered items have an identifier
 * and a state.
 */

// Obviously these should not be globals but it's fine for now.
var node2registered = [SCNNode:Registered]()
var id2node = [Int16:SCNNode]()
var counter: Int16 = 0
var registry = Set<Registered>()

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
}
