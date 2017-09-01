import Foundation
import SceneKit

enum InputCommand {
    case pointOfView(id: UInt16)
    case toss(id: UInt16)
    case voxel(id: UInt16, color: UIColor)
    case sphere(id: UInt16)
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
        case 2:
            let id = UInt16(dataWrapper: dataWrapper)
            let red = UInt8(dataWrapper: dataWrapper)
            let green = UInt8(dataWrapper: dataWrapper)
            let blue = UInt8(dataWrapper: dataWrapper)
            self = .voxel(id: id, color: UIColor(red: CGFloat(red) / 255, green: CGFloat(green) / 255, blue: CGFloat(blue) / 255, alpha: 1))
        case 3:
            let id = UInt16(dataWrapper: dataWrapper)
            self = .sphere(id: id)
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
        case let .voxel(id: id, color: color):
            mutableData.append(UInt8(2).data)
            mutableData.append(id.data)
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            var alpha: CGFloat = 0
            color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            mutableData.append(UInt8(red * 255).data)
            mutableData.append(UInt8(green * 255).data)
            mutableData.append(UInt8(blue * 255).data)
        case let .sphere(id: id):
            mutableData.append(UInt8(1).data)
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
        case let .pointOfView(id: id):
            let node = createAxesNode(quiverLength: 0.1, quiverThickness: 1.0)
            //        let fire = SCNScene(named: "scene.scn", inDirectory: "Models.scnassets/Fire")!.rootNode.childNodes.first!
            scene.rootNode.addChildNode(node)
            registrar.register(node, id: id)
        case let .toss(id: id):
            let node = Ball()
            scene.rootNode.addChildNode(node)
            registrar.register(node, id: id)
        case let .voxel(id: id, color: color):
            let node = Voxel.node(color: color)
            scene.rootNode.addChildNode(node)
            registrar.register(node, id: id)
        case let .sphere(id: id):
            let node = Sphere()
            scene.rootNode.addChildNode(node)
            registrar.register(node, id: id)
        }
    }

    func nodeMissing(with state: NodeState) {
        fatalError("missing node \(state)")
    }
}


