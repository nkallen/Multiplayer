import Foundation
import SceneKit

enum Kind: UInt8 {
    case pov, toss, sphere, voxel
}

enum InputCommand {
    case create(Kind, id: UInt16)
    case voxel(id: UInt16, color: UIColor)
}

extension InputCommand: DataConvertible {
    static let minimumSizeInBytes = 3

    init(dataWrapper: DataWrapper) {
        guard dataWrapper.count >= InputCommand.minimumSizeInBytes else { fatalError("Invalid number of bytes") }
        let type = Kind(rawValue: UInt8(dataWrapper: dataWrapper))!
        switch type {
        case .pov, .toss, .sphere:
            let id = UInt16(dataWrapper: dataWrapper)
            self = .create(type, id: id)
        case .voxel:
            let id = UInt16(dataWrapper: dataWrapper)
            let color = UIColor(dataWrapper: dataWrapper)
            self = .voxel(id: id, color: color)
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
        case let .voxel(id: id, color: color):
            mutableData.append(Kind.voxel.rawValue.data)
            mutableData.append(id.data)
            mutableData.append(color.data)
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
        case let .create(.toss, id: id):
            let node = Ball()
            scene.rootNode.addChildNode(node)
            registrar.register(node, id: id)
        case let .create(.sphere, id: id):
            let node = Sphere()
            scene.rootNode.addChildNode(node)
            registrar.register(node, id: id)
        case let .voxel(id: id, color: color):
            let node = Voxel.node(color: color)
            scene.rootNode.addChildNode(node)
            registrar.register(node, id: id)
        default: fatalError()
        }
    }

    func nodeMissing(with state: NodeState) {
        fatalError("missing node \(state)")
    }
}


