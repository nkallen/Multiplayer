import UIKit
import QuartzCore
import SceneKit
import GameKit

class GameViewController: UIViewController, SCNSceneRendererDelegate {
    var screenRecordingManager: ScreenRecordingManager!

    @IBOutlet weak var sceneView: SCNView!
    @IBOutlet weak var sequenceLabel: UILabel!
    @IBOutlet var nonRecordingView: UIView!

    var multiplayer: GameKitMultiplayer<MyInputInterpreter>!
    var inputInterpreter: MyInputInterpreter!

    override func viewDidLoad() {
        super.viewDidLoad()

        setupScene()
        inputInterpreter = MyInputInterpreter(scene: sceneView.scene!)
        multiplayer = GameKitMultiplayer(inputInterpreter: inputInterpreter)

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        sceneView.addGestureRecognizer(tapGesture)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        screenRecordingManager = ScreenRecordingManager(frame: view.frame, view: nonRecordingView)
    }

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        renderer.isPlaying = true
        multiplayer.renderedFrame(updateAtTime: time, of: sceneView.scene!)
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

    // MARK: - Scene gunk

    func setupScene() {
        let scene = SCNScene(named: "art.scnassets/ship.scn")!

        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        scene.rootNode.addChildNode(cameraNode)
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 15)
        _ = multiplayer.localState.register(cameraNode, priority: 1) { registered in
            self.multiplayer.localState.input(.create(.pov, id: registered.id))
        }

        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light!.type = .omni
        lightNode.position = SCNVector3(x: 0, y: 10, z: 10)
        scene.rootNode.addChildNode(lightNode)

        let ambientLightNode = SCNNode()
        ambientLightNode.light = SCNLight()
        ambientLightNode.light!.type = .ambient
        ambientLightNode.light!.color = UIColor.darkGray
        scene.rootNode.addChildNode(ambientLightNode)

        sceneView.scene = scene
        sceneView.allowsCameraControl = true
        sceneView.showsStatistics = true
        sceneView.backgroundColor = UIColor.black

        sceneView.delegate = self
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

extension SCNMaterial {
    static func material(withDiffuse diffuse: Any?, respondsToLighting: Bool = true) -> SCNMaterial {
        let material = SCNMaterial()
        material.diffuse.contents = diffuse
        material.isDoubleSided = true
        if respondsToLighting {
            material.locksAmbientWithDiffuse = true
        } else {
            material.ambient.contents = UIColor.black
            material.lightingModel = .constant
            material.emission.contents = diffuse
        }
        return material
    }
}

// MARK: - Simple geometries

func createAxesNode(quiverLength: CGFloat, quiverThickness: CGFloat) -> SCNNode {
    let quiverThickness = (quiverLength / 50.0) * quiverThickness
    let chamferRadius = quiverThickness / 2.0

    let xQuiverBox = SCNBox(width: quiverLength, height: quiverThickness, length: quiverThickness, chamferRadius: chamferRadius)
    xQuiverBox.materials = [SCNMaterial.material(withDiffuse: UIColor.red, respondsToLighting: false)]
    let xQuiverNode = SCNNode(geometry: xQuiverBox)
    xQuiverNode.position = SCNVector3Make(Float(quiverLength / 2.0), 0.0, 0.0)

    let yQuiverBox = SCNBox(width: quiverThickness, height: quiverLength, length: quiverThickness, chamferRadius: chamferRadius)
    yQuiverBox.materials = [SCNMaterial.material(withDiffuse: UIColor.green, respondsToLighting: false)]
    let yQuiverNode = SCNNode(geometry: yQuiverBox)
    yQuiverNode.position = SCNVector3Make(0.0, Float(quiverLength / 2.0), 0.0)

    let zQuiverBox = SCNBox(width: quiverThickness, height: quiverThickness, length: quiverLength, chamferRadius: chamferRadius)
    zQuiverBox.materials = [SCNMaterial.material(withDiffuse: UIColor.blue, respondsToLighting: false)]
    let zQuiverNode = SCNNode(geometry: zQuiverBox)
    zQuiverNode.position = SCNVector3Make(0.0, 0.0, Float(quiverLength / 2.0))

    let quiverNode = SCNNode()
    quiverNode.addChildNode(xQuiverNode)
    quiverNode.addChildNode(yQuiverNode)
    quiverNode.addChildNode(zQuiverNode)
    quiverNode.name = "Axes"
    return quiverNode
}
