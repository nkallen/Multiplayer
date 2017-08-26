import XCTest
import SceneKit
@testable import Multiplayer

class StateTests: XCTestCase {
    let position = float3(1,1,1)
    let orientation = float4(2,2,2,2)
    let linearVelocity = float3(3,3,3)
    let angularVelocity = float3(4,4,4)

    func testCompactSerialization() {
        XCTAssertEqual(80, MemoryLayout<FullNodeState>.size)
        XCTAssertEqual(48, MemoryLayout<CompactNodeState>.size)
    }

    func testNodeStateSerialization() {
        let nodeState = FullNodeState(id: 1, position: position, orientation: orientation, linearVelocity: linearVelocity, angularVelocity: angularVelocity)

        let data = nodeState.data
        let deserialized = FullNodeState(data: data)!
        XCTAssertEqual(nodeState, deserialized)
    }

    func testPacketSerialization() {
        let nodeState1 = FullNodeState(id: 1, position: position, orientation: orientation, linearVelocity: linearVelocity, angularVelocity: angularVelocity)
        let nodeState2 = CompactNodeState(id: 2, position: position, orientation: orientation)

        let updates: [NodeState] = [nodeState1, nodeState2]
        let packet = Packet(sequence: 5, updates: updates)
        let data = packet.data
        let deserialized = Packet(data: data)
        XCTAssertEqual(packet, deserialized)
    }

    func testPriorityAccumulator() {
        let node1 = HasPriority(intrinsicPriority: 1, node: SCNNode())
        let node2 = HasPriority(intrinsicPriority: 1.1, node: SCNNode())
        let priorityAccumulator = PriorityAccumulator()
        priorityAccumulator.all = [node1, node2]
        priorityAccumulator.update()
        XCTAssertEqual([node2], priorityAccumulator.top(1))
        priorityAccumulator.update()
        XCTAssertEqual([node1], priorityAccumulator.top(1))
        priorityAccumulator.update()
        XCTAssertEqual([node2], priorityAccumulator.top(1))
    }
}
