import Foundation
import SceneKit

enum Kind: UInt8 {
    case pov
}

enum InputCommand {
    case create(Kind, id: UInt16)
}

extension InputCommand: DataConvertible {
    static let minimumSizeInBytes = 3

    init(dataWrapper: DataWrapper) {
        guard dataWrapper.count >= InputCommand.minimumSizeInBytes else { fatalError("Invalid number of bytes") }
        let type = Kind(rawValue: UInt8(dataWrapper: dataWrapper))!
        switch type {
        case .pov:
            let id = UInt16(dataWrapper: dataWrapper)
            self = .create(type, id: id)
        default:
            fatalError("invalid type")
        }
    }

    var data: Data {
        let mutableData = NSMutableData()
        switch self {
        case let .create(kind, id: id):
            mutableData.append(kind.rawValue.data)
            mutableData.append(id.data)
        }
        return mutableData as Data
    }
}

class MyInputInterpreter: InputInterpreter {
    typealias T = InputCommand
    let scene: SCNScene

    init(scene: SCNScene) {
        self.scene = scene
    }

    func apply(input: InputCommand, with registrar: ReadRegistrar) {
        switch input {
        case let .create(.pov, id: id):
            let node = createAxesNode(quiverLength: 0.1, quiverThickness: 1.0)
            //        let fire = SCNScene(named: "scene.scn", inDirectory: "Models.scnassets/Fire")!.rootNode.childNodes.first!
            scene.rootNode.addChildNode(node)
            registrar.register(node, id: id)
        default: fatalError()
        }
    }

    func nodeMissing(with state: NodeState) {
        fatalError("missing node \(state)")
    }
}


