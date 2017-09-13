import UIKit
import QuartzCore
import SceneKit
import GameKit

class GameViewController: UIViewController {
    var screenRecordingManager: ScreenRecordingManager!

    @IBOutlet weak var sceneView: SceneView!
    @IBOutlet weak var sequenceLabel: UILabel!
    @IBOutlet var nonRecordingView: UIView!

    var multiplayer: GameKitMultiplayer<MyInputInterpreter>!
    var inputInterpreter: MyInputInterpreter!

    override func viewDidLoad() {
        super.viewDidLoad()

        inputInterpreter = MyInputInterpreter(scene: sceneView.scene!)
        multiplayer = GameKitMultiplayer(inputInterpreter: inputInterpreter)
        sceneView.multiplayer = multiplayer
//        _ = multiplayer.localState.register(cameraNode, priority: 1) { registered in
//            self.multiplayer.localState.input(.create(.pov, id: registered.id))
//        }

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        sceneView.addGestureRecognizer(tapGesture)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        screenRecordingManager = ScreenRecordingManager(frame: view.frame, view: nonRecordingView)
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
        sceneView.scene?.rootNode.addChildNode(node)
    }

    // MARK: - Recording

    @IBOutlet weak var recordingButton: UIButton!

    @IBAction func didPressRecordButton(_ sender: UIButton) {
        if screenRecordingManager.isRecording {
            screenRecordingManager.toggleRecording()
            recordingButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        } else {
            screenRecordingManager.toggleRecording()
            self.recordingButton.backgroundColor = UIColor.red.withAlphaComponent(0.5)
        }
    }
}
