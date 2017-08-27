import XCTest
import SceneKit
@testable import Multiplayer

class StateTests: XCTestCase {
    let position = float3(1,1,1)
    let eulerAngles = float3(2,2,2)
    let linearVelocity = float3(3,3,3)
    let angularVelocity = float3(4,4,4)

    func testCompactSerialization() {
        XCTAssertEqual(80, MemoryLayout<FullNodeState>.size)
        XCTAssertEqual(48, MemoryLayout<CompactNodeState>.size)
    }

    func testNodeStateSerialization() {
        let nodeState = FullNodeState(id: 1, position: position, eulerAngles: eulerAngles, linearVelocity: linearVelocity, angularVelocity: angularVelocity)

        let data = nodeState.data
        let deserialized = FullNodeState(data: data)!
        XCTAssertEqual(nodeState, deserialized)
    }

    func testPacketSerialization() {
        let nodeState1 = FullNodeState(id: 1, position: position, eulerAngles: eulerAngles, linearVelocity: linearVelocity, angularVelocity: angularVelocity)
        let nodeState2 = CompactNodeState(id: 2, position: position, eulerAngles: eulerAngles)

        let updates: [NodeState] = [nodeState1, nodeState2]
        let packet = Packet(sequence: 5, updates: updates)
        let data = packet.data
        let deserialized = Packet(data: data)
        XCTAssertEqual(packet, deserialized)
    }

    func testPriorityAccumulator() {
        let node1 = AdHocPriorityNode(priority: 1)
        let node2 = AdHocPriorityNode(priority: 1.1)
        node1.register(); node2.register()
        let priorityAccumulator = PriorityAccumulator()
        priorityAccumulator.update()
        XCTAssertEqual([node2], priorityAccumulator.top(1))
        priorityAccumulator.update()
        XCTAssertEqual([node1], priorityAccumulator.top(1))
        priorityAccumulator.update()
        XCTAssertEqual([node2], priorityAccumulator.top(1))
    }

    func testJitterBuffer() {
        let p1 = Packet(sequence: 0, updates: [])
        let p2 = Packet(sequence: 1, updates: [])
        let p3 = Packet(sequence: 2, updates: [])
        let p4 = Packet(sequence: 3, updates: [])
        let jitterBuffer = JitterBuffer(capacity: 1024, minDelay: 3)

        XCTAssertNil(jitterBuffer[0])
        jitterBuffer.push(p3)
        XCTAssertNil(jitterBuffer[1])
        jitterBuffer.push(p1)
        XCTAssertNil(jitterBuffer[2])
        jitterBuffer.push(p2)
        XCTAssertEqual(p1, jitterBuffer[3])
        jitterBuffer.push(p1)
        XCTAssertEqual(p2, jitterBuffer[4])
        jitterBuffer.push(p4)
        XCTAssertEqual(p3, jitterBuffer[5])
    }
}

class AdHocPriorityNode: SCNNode, HasPriority {
    let intrinsicPriority: Float

    init(priority: Float) {
        self.intrinsicPriority = priority
        super.init()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
