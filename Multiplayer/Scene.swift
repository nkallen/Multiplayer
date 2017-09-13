import Foundation
import SceneKit

class SceneView: SCNView, SCNSceneRendererDelegate {
    var multiplayer: GameKitMultiplayer<MyInputInterpreter>!
    var inputInterpreter: MyInputInterpreter!

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        self.scene = SCNScene(named: "art.scnassets/scene.scn")!
        allowsCameraControl = true
        showsStatistics = true
        backgroundColor = UIColor.black

        inputInterpreter = MyInputInterpreter(scene: scene!)
        multiplayer = GameKitMultiplayer(inputInterpreter: inputInterpreter)

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tapGesture)

        delegate = self
    }

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        renderer.isPlaying = true
        multiplayer.renderedFrame(updateAtTime: time, of: scene!)
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
