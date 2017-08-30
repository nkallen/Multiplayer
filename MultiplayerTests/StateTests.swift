import XCTest
import SceneKit
@testable import Ark

class StateTests: XCTestCase {
    let position = float3(1,1,1)
    let orientation = float4(2,2,2,2)
    let linearVelocity = float3(3,3,3)
    let angularVelocity = float4(4,4,4,4)

    func testCompactNodeStateSerialization() {
        let nodeState = CompactNodeState(id: 1, position: position, orientation: orientation)

        let data = nodeState.data
        let deserialized = CompactNodeState(dataWrapper: DataWrapper(data))!
        XCTAssertEqual(nodeState, deserialized)
    }

    func testFullNodeStateSerialization() {
        let nodeState = FullNodeState(id: 1, position: position, orientation: orientation, linearVelocity: linearVelocity, angularVelocity: angularVelocity)

        let data = nodeState.data
        let deserialized = FullNodeState(dataWrapper: DataWrapper(data))!
        XCTAssertEqual(nodeState, deserialized)
    }


    func testPacketSerialization() {
        let nodeState1 = FullNodeState(id: 1, position: position, orientation: orientation, linearVelocity: linearVelocity, angularVelocity: angularVelocity)
        let nodeState2 = CompactNodeState(id: 2, position: position, orientation: orientation)

        let updates: [NodeState] = [nodeState1, nodeState2]
        let packet = Packet(sequence: 5, updates: updates, inputs: [])
        let data = packet.data
        let deserialized = Packet(dataWrapper: DataWrapper(data))
        XCTAssertEqual(packet, deserialized)
    }

    func testPriorityAccumulator() {
        let stateSynchronizer = StateSynchronizer()
        let node1 = AdHocPriorityNode(priority: 1)
        let node2 = AdHocPriorityNode(priority: 1.1)
        let registered1 = stateSynchronizer.register(node1)
        let registered2 = stateSynchronizer.register(node2)
        let priorityAccumulator = PriorityAccumulator()
        priorityAccumulator.update(registry: stateSynchronizer.registry)
        XCTAssertEqual([registered2], priorityAccumulator.top(1, in: stateSynchronizer.registry))
        priorityAccumulator.update(registry: stateSynchronizer.registry)
        XCTAssertEqual([registered1], priorityAccumulator.top(1, in: stateSynchronizer.registry))
        priorityAccumulator.update(registry: stateSynchronizer.registry)
        XCTAssertEqual([registered2], priorityAccumulator.top(1, in: stateSynchronizer.registry))
    }

    func testInputBuffer() {
        let input1 = Input(sequence: 0, type: 0, nodeId: 1)
        let input2 = Input(sequence: 1, type: 0, nodeId: 1)
        let input3 = Input(sequence: 2, type: 1, nodeId: 1)
        let input4 = Input(sequence: 3, type: 1, nodeId: 2)
        let input5 = Input(sequence: 4, type: 1, nodeId: 3)
        let inputBuffer = InputWindowBuffer(capacity: 10)
        inputBuffer.push(input1)
        inputBuffer.push(input2)
        inputBuffer.push(input3)
        inputBuffer.push(input4)
        inputBuffer.push(input5)

        XCTAssertEqual([input1], inputBuffer.top(5, at: 0))
        XCTAssertEqual([input1, input2], inputBuffer.top(5, at: 1))
        XCTAssertEqual([input1, input2, input3], inputBuffer.top(5, at: 2))
        XCTAssertEqual([input1, input2, input3, input4], inputBuffer.top(5, at: 3))
        XCTAssertEqual([input1, input2, input3, input4, input5], inputBuffer.top(5, at: 4))
        XCTAssertEqual([input2, input3, input4, input5], inputBuffer.top(5, at: 5))
        XCTAssertEqual([input3, input4, input5], inputBuffer.top(5, at: 6))
        XCTAssertEqual([], inputBuffer.top(5, at: 11))
    }

    func testInputBufferAtInt16Wrap() {
        let input1 = Input(sequence: 0, type: 0, nodeId: 1)
        let input2 = Input(sequence: 1, type: 0, nodeId: 1)
        let inputBuffer = InputWindowBuffer(capacity: 10)

        inputBuffer.push(input1)
        inputBuffer.push(input2)
        XCTAssertEqual([], inputBuffer.top(10, at: 100))
        XCTAssertEqual([], inputBuffer.top(5, at: 4))
        inputBuffer.push(input1)
        inputBuffer.push(input2)
        XCTAssertEqual([input1, input2], inputBuffer.top(5, at: 4))
    }

    class FakeInputInterpreter: InputInterpreter {
        var applied = [(UInt8, Int16)]()

        func apply(type: UInt8, id: Int16) {
            applied.append((type, id))
        }
    }

    func testInputReadQueue() {
        let inputReadQueue = InputReadQueue(capacity: 100)
        let inputInterpreter = FakeInputInterpreter()
        let input1 = Input(sequence: 0, type: 0, nodeId: 0)
        let input2 = Input(sequence: 1, type: 1, nodeId: 1)
        let input3 = Input(sequence: 2, type: 2, nodeId: 2)
        XCTAssertEqual(0, inputInterpreter.applied.count)
        inputReadQueue.apply(inputs: [input1, input2], inputInterpreter: inputInterpreter)
        XCTAssertEqual(2, inputInterpreter.applied.count)
        inputReadQueue.apply(inputs: [input1, input2, input3], inputInterpreter: inputInterpreter)
        XCTAssertEqual(3, inputInterpreter.applied.count)
    }

    func testJitterBuffer() {
        let p1 = Packet(sequence: 0, updates: [], inputs: [])
        let p2 = Packet(sequence: 1, updates: [], inputs: [])
        let p3 = Packet(sequence: 2, updates: [], inputs: [])
        let p4 = Packet(sequence: 3, updates: [], inputs: [])
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
