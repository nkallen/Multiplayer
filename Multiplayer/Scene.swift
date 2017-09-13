import Foundation
import SceneKit
import GameKit

class SceneView: SCNView, SCNSceneRendererDelegate {
    var multiplayer: GameKitMultiplayer<MyInputInterpreter>!
    var inputInterpreter: MyInputInterpreter!
    var lastUpdateTime: TimeInterval?
    var gkScene: GKScene!

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        let scene = SCNScene(named: "art.scnassets/scene.scn")!
        self.scene = scene
        self.gkScene = MyGKScene(scene: scene)
        allowsCameraControl = true
        showsStatistics = true
        backgroundColor = UIColor.black

        inputInterpreter = MyInputInterpreter(scene: scene)
        multiplayer = GameKitMultiplayer(inputInterpreter: inputInterpreter)

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tapGesture)

        delegate = self
    }

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        renderer.isPlaying = true
        multiplayer.renderedFrame(updateAtTime: time, of: scene!)

        if self.lastUpdateTime == nil {
            self.lastUpdateTime = time
        }
        let lastUpdateTime = self.lastUpdateTime!

        let delta = time - lastUpdateTime
        for entity in gkScene.entities {
            entity.update(deltaTime: delta)
            let agent = entity.component(ofType: GKAgent3D.self)
        }
        self.lastUpdateTime = time
    }

    // Mark: Interaction

    @objc
    func handleTap(_ gestureRecognize: UIGestureRecognizer) {
        createBox()
    }

    func createBox() {
        let box = SCNBox(width: 1, height: 1, length: 1, chamferRadius: 0)
        box.firstMaterial = SCNMaterial.material(withDiffuse: UIColor.blue.withAlphaComponent(0.5))
        let node = SCNNode(geometry: box)
        node.simdPosition = float3(0, 10, 0)
        node.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
        _ = multiplayer.localState.register(node, priority: 1) { registered in
            self.multiplayer.localState.input(.create(.pov, id: registered.id))
        }
        scene!.rootNode.addChildNode(node)
    }
}

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
            agent.position = float3(node.position)

            let rotation = node.rotation
            let rotationMatrix = SCNMatrix4MakeRotation(rotation.w, rotation.x, rotation.y, rotation.z)
            agent.rotation = convertToFloat3x3(float4x4: float4x4(rotationMatrix))

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
    }

    override func agentDidUpdate(_ agent: GKAgent) {
//        print("agent did update", (agent as! GKAgent3D).rotation)
//        super.agentDidUpdate(agent)
        guard let agent = agent as? GKAgent3D else { return }

        let rotation3x3 = agent.rotation
        let rotation4x4 = convertToFloat4x4(float3x3: rotation3x3)
        let rotationMatrix = SCNMatrix4(rotation4x4)
        let position = agent.position
        let translationMatrix = SCNMatrix4MakeTranslation(position.x, position.y, position.z)
        node.transform = SCNMatrix4Mult(rotationMatrix, translationMatrix)
    }
}
