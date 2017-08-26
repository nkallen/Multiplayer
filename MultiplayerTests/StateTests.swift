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

    func testJitterBuffer() {
        let p1 = Packet(sequence: 1, updates: [])
        let p2 = Packet(sequence: 2, updates: [])
        let p3 = Packet(sequence: 3, updates: [])
        let p4 = Packet(sequence: 4, updates: [])
        let jitterBuffer = JitterBuffer(delay: 3)

        XCTAssertNil(jitterBuffer.pop())
        jitterBuffer.push(p3)
        XCTAssertNil(jitterBuffer.pop())
        jitterBuffer.push(p1)
        XCTAssertNil(jitterBuffer.pop())
        jitterBuffer.push(p2)
        XCTAssertEqual(p1, jitterBuffer.pop())
        jitterBuffer.push(p1)
        XCTAssertNil(jitterBuffer.pop())
        jitterBuffer.push(p4)
        XCTAssertEqual(p2, jitterBuffer.pop())
    }
}
