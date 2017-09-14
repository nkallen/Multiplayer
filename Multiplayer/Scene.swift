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

        let delta = time - self.lastUpdateTime!
        for entity in gkScene.entities {
            entity.update(deltaTime: delta)
        }
        self.lastUpdateTime = time
    }

    // Mark: Interaction

    @objc
    func handleTap(_ gestureRecognize: UIGestureRecognizer) {
    }
}
