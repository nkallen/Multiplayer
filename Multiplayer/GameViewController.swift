import UIKit
import QuartzCore
import SceneKit
import GameKit

class GameViewController: UIViewController, GKLocalPlayerListener, GKMatchDelegate, SCNSceneRendererDelegate {

    let jitterBuffer = JitterBuffer(capacity: 1024)

    override func viewDidLoad() {
        super.viewDidLoad()

        setupScene()

        let scnView = self.view as! SCNView
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        scnView.addGestureRecognizer(tapGesture)

        setupGame()

        let url = documentDirectory.appendingPathComponent("packets.dat")
        let data = try! Data(contentsOf: url)
        let dataWrapper = DataWrapper(data)
        while let packet = Packet(dataWrapper: dataWrapper) {
            jitterBuffer.push(packet)
        }
    }

    // MARK: - GameKit

    var host: GKPlayer?

    func setupGame() {
        let localPlayer = GKLocalPlayer.localPlayer()
        localPlayer.authenticateHandler = { (viewController, error) in
            if error == nil {
                if let viewController = viewController,
                    let delegate = UIApplication.shared.delegate,
                    let window = delegate.window,
                    let rootViewController = window?.rootViewController {
                    rootViewController.present(viewController, animated: true) { () in
                        print("completed")
                    }
                } else {
                    self.startMatch()
                }
            }
        }
    }

    var firstUpdateTime: TimeInterval?
    func startMatch() {
        let localPlayer = GKLocalPlayer.localPlayer()
        let matchRequest = GKMatchRequest()
        matchRequest.minPlayers = 2
        GKMatchmaker.shared().findMatch(for: matchRequest) { (match, error) in
            if let match = match {
                print("found match", match)
                match.delegate = self

            }
        }
    }

    func match(_ match: GKMatch, didFailWithError error: Error?) {
        print("failure with error", error)
    }

    func match(_ match: GKMatch, didReceive data: Data, fromRemotePlayer player: GKPlayer) {
        print("did receive data")
    }

    func match(_ match: GKMatch, player: GKPlayer, didChange state: GKPlayerConnectionState) {
        print(match.players, match.expectedPlayerCount)
        print("player", player, "changed state to", state)
    }

    func frameCount(updatedAtTime time: TimeInterval) -> Int {
        let deltaTime: TimeInterval = time - self.firstUpdateTime!
        return Int(deltaTime * 60)
    }

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        if firstUpdateTime == nil {
            self.firstUpdateTime = time
        }
        let scnView = self.view as! SCNView
        if let packet = jitterBuffer[frameCount(updatedAtTime: time)] {
            scnView.scene!.apply(packet: packet)
        }
    }

    func renderer(_ renderer: SCNSceneRenderer, didRenderScene scene: SCNScene, atTime time: TimeInterval) {
        print("rendering")
    }

    var data = NSMutableData()
    let documentDirectory = FileManager.default.urls(for: .documentDirectory, in:.userDomainMask).first!

    func renderer(_ renderer: SCNSceneRenderer, didSimulatePhysicsAtTime time: TimeInterval) {
//        let scnView = self.view as! SCNView
//        let packet = scnView.scene!.packet(sequence: frameCount)
//        data.append(packet.data)
//        if frameCount == 1000 {
//            print("writing....")
//            //            try! data.write(to: documentDirectory.appendingPathComponent("packets.dat"))
//        }

    }

    @objc
    func handleTap(_ gestureRecognize: UIGestureRecognizer) {
        createBox()
    }

    func createBox() {
        let scnView = self.view as! SCNView
        let box = SCNBox(width: 1, height: 1, length: 1, chamferRadius: 0)
        box.firstMaterial = SCNMaterial.material(withDiffuse: UIColor.blue.withAlphaComponent(0.5))
        let node = SCNNode(geometry: box)
        node.simdPosition = float3(0, 10, 0)
        node.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
        node.register()
        scnView.scene?.rootNode.addChildNode(node)
    }

    func setupScene() {
        let scene = SCNScene(named: "art.scnassets/ship.scn")!

        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        scene.rootNode.addChildNode(cameraNode)
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 15)

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

        let scnView = self.view as! SCNView
        scnView.scene = scene
        scnView.allowsCameraControl = true
        scnView.showsStatistics = true
        scnView.backgroundColor = UIColor.black

        scnView.delegate = self
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
