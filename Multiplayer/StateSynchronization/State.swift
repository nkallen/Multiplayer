import Foundation
import SceneKit

extension SCNNode {
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
