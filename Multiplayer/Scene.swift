import Foundation
import SceneKit

class SceneView: SCNView, SCNSceneRendererDelegate {
    weak var multiplayer: GameKitMultiplayer<MyInputInterpreter>!

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        self.scene = SCNScene(named: "art.scnassets/scene.scn")!
        allowsCameraControl = true
        showsStatistics = true
        backgroundColor = UIColor.black

        delegate = self
    }

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        renderer.isPlaying = true
        multiplayer.renderedFrame(updateAtTime: time, of: scene!)
    }
}
