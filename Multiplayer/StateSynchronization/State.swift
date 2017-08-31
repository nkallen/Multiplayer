import Foundation
import SceneKit

// MARK: - Nodes

extension SCNNode {
    func update(to state: NodeState, with referenceNode: SCNNode) {
        let position = state.position
        let orientation = simd_quatf(ix: state.orientation.x, iy: state.orientation.y, iz: state.orientation.z, r: state.orientation.w)
        var transform = float4x4(orientation)
        transform.columns.3 = float4(position.x, position.y, position.z, 1)

        simdWorldTransform = referenceNode.simdWorldTransform * transform
//        print("in update:", simdWorldPosition, simdWorldOrientation)

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
    var orientation: float4 { get }
    var linearVelocity: float3 { get }
    var angularVelocity: float4 { get }
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
    let id: Int16
    let position: float3
    let orientation: float4
    var linearVelocity: float3 { return float3(0,0,0) }
    var angularVelocity: float4 { return float4(0,0,0,0) }

    static func ==(lhs: CompactNodeState, rhs: CompactNodeState) -> Bool {
        return lhs.id == rhs.id &&
            lhs.position == rhs.position &&
            lhs.orientation == rhs.orientation &&
            lhs.linearVelocity == rhs.linearVelocity &&
            lhs.angularVelocity == rhs.angularVelocity
    }
}

struct FullNodeState: NodeState, Equatable {
    let id: Int16 // 2
    let position: float3 // 4 *3
    let orientation: float4 // 4*4
    let linearVelocity: float3 // 4*3
    let angularVelocity: float4 // 4*4

    static func ==(lhs: FullNodeState, rhs: FullNodeState) -> Bool {
        return lhs.id == rhs.id &&
            lhs.position == rhs.position &&
            lhs.orientation == rhs.orientation &&
            lhs.linearVelocity == rhs.linearVelocity &&
            lhs.angularVelocity == rhs.angularVelocity
    }
}

// MARK: - Input

struct Input: Equatable, Hashable {
    let sequence: Int16
    let type: UInt8
    let nodeId: Int16

    static func ==(lhs: Input, rhs: Input) -> Bool {
        return lhs.sequence == rhs.sequence &&
            lhs.type == rhs.type &&
            lhs.nodeId == rhs.nodeId
    }

    var hashValue: Int {
        return Int(sequence)
    }
}
