import Foundation
import GameKit
import SceneKit

class MyGKScene: GKScene {
    let separationWeight: Float = 10
    let separationAngle: Float = 3 * .pi / 4.0
    let separationRadius: Float = 0.553 * 50

    let alignmentWeight: Float = 12.66
    let alignmentRadius: Float = 0.83333 * 50
    let alignmentAngle: Float = .pi / 4

    let cohesionWeight: Float = 8.66
    let cohesionRadius: Float = 1.0 * 100
    let cohesionAngle: Float = .pi / 2

    let wanderWeight: Float = 1.0

    let scene: SCNScene

    init(scene: SCNScene) {
        self.scene = scene
        super.init()

        let shipScene = SCNScene(named: "art.scnassets/ship.scn")!
        let shipNode = shipScene.rootNode.childNode(withName: "ship", recursively: false)!
        let agents: [GKAgent] = Array(0...10).map { i in
            let node = shipNode.clone()
            scene.rootNode.addChildNode(node)
            node.simdPosition = float3(0, Float(i), Float(i))

            let entity = GKEntity()
            let agent = GKAgent3D()
            agent.mass = 1
            agent.maxSpeed = 10
            agent.maxAcceleration = 5

            let nodeComponent = NodeComponent(node: node)
            agent.delegate = nodeComponent


            entity.addComponent(agent)
            entity.addComponent(nodeComponent)
            addEntity(entity)
            return agent
        }
        do {
            let behavior = GKBehavior()
            behavior.setWeight(separationWeight, for: GKGoal(toSeparateFrom: agents, maxDistance: separationRadius, maxAngle: separationAngle))
            behavior.setWeight(alignmentWeight, for: GKGoal(toAlignWith: agents, maxDistance: alignmentRadius, maxAngle: alignmentAngle))
            behavior.setWeight(cohesionWeight, for: GKGoal(toCohereWith: agents, maxDistance: cohesionRadius, maxAngle: cohesionAngle))
            behavior.setWeight(1, for: GKGoal(toSeekAgent: agents.first!))

            for agent in agents {
                agent.behavior = behavior
            }
            agents.first!.behavior = nil
            (agents.first as! GKAgent3D).position = float3(0,0,30)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class NodeComponent: GKSCNNodeComponent {
    override func agentWillUpdate(_ agent: GKAgent) {
        guard let agent = agent as? GKAgent3D else { return }

        agent.transform = node.simdTransform
    }

    override func agentDidUpdate(_ agent: GKAgent) {
        guard let agent = agent as? GKAgent3D else { return }

        node.simdTransform = agent.transform
    }
}

extension GKAgent3D {
    static let to = float4x4(SCNMatrix4MakeRotation(.pi / 2, 0, 1, 0))
    static let from = float4x4(SCNMatrix4MakeRotation(-.pi / 2, 0, 1, 0))

    var transform: float4x4 {
        get {
            var transform = GKAgent3D.to * float4x4(float3x3: rotation)
            transform.columns.3 = float4(float3: position)

            return transform
        }

        set(newTransform) {
            self.rotation = float3x3(float4x4: GKAgent3D.from * newTransform)
            self.position = float3(float4: newTransform.columns.3)
        }
    }
}


