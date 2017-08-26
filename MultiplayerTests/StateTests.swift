import XCTest
import SceneKit
@testable import Multiplayer

class StateTests: XCTestCase {

    func testCompactSerialization() {
        XCTAssertEqual(80, MemoryLayout<FullNodeState>.size)
        XCTAssertEqual(48, MemoryLayout<CompactNodeState>.size)
    }

    func testSerialization() {
        let position = float3(1,1,1)
        let orientation = float4(2,2,2,2)
        let linearVelocity = float3(3,3,3)
        let angularVelocity = float3(4,4,4)

        let nodeState = FullNodeState(id: 1, position: position, orientation: orientation, linearVelocity: linearVelocity, angularVelocity: angularVelocity)
        let data = nodeState.data
        let deserialized = FullNodeState(data: data)
        XCTAssertEqual(nodeState, deserialized)
    }
    
}
