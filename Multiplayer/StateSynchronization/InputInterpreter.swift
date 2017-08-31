import Foundation
import SceneKit

enum InputCommand {
    case pointOfView(id: UInt16)
    case toss(id: UInt16)
}

extension InputCommand: DataConvertible {
    static let minimumSizeInBytes = 3

    init(dataWrapper: DataWrapper) {
        guard dataWrapper.count >= InputCommand.minimumSizeInBytes else { fatalError("Invalid number of bytes") }
        let type = UInt8(dataWrapper: dataWrapper)
        switch type {
        case 0:
            let id = UInt16(dataWrapper: dataWrapper)
            self = .pointOfView(id: id)
        case 1:
            let id = UInt16(dataWrapper: dataWrapper)
            self = .toss(id: id)
        default:
            fatalError("invalid type")
        }
    }

    var data: Data {
        let mutableData = NSMutableData()
        switch self {
        case let .pointOfView(id: id):
            mutableData.append(UInt8(0).data)
            mutableData.append(id.data)
        case let .toss(id: id):
            mutableData.append(UInt8(1).data)
            mutableData.append(id.data)
        }
        return mutableData as Data
    }
}

class MyInputInterpreter: InputInterpreter {
    let scene: SCNScene

    init(scene: SCNScene) {
        self.scene = scene
    }

    func apply(input: Data, from remote: StateSynchronizer) {
//        switch type {
//        case 0:
//            let node = createAxesNode(quiverLength: 0.1, quiverThickness: 1.0)
//            //        let fire = SCNScene(named: "scene.scn", inDirectory: "Models.scnassets/Fire")!.rootNode.childNodes.first!
//            scene.rootNode.addChildNode(node)
//            _ = remote.register(node, priority: 1)
//        case 1:
//            let node = Ball()
//            scene.rootNode.addChildNode(node)
//            _ = remote.register(node, priority: 1)
//        default:
//            fatalError("Invalid type")
//        }
    }

    func nodeMissing(with state: NodeState) {
        fatalError("missing node \(state)")
    }
}
