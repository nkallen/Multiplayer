import UIKit
import QuartzCore
import SceneKit
import GameKit

class GameViewController: UIViewController, GKLocalPlayerListener, GKMatchDelegate, SCNSceneRendererDelegate {

    @IBOutlet weak var sceneView: SCNView!
    @IBOutlet weak var sequenceLabel: UILabel!

    enum State {
        case await
        case joinedMatch
        case playing(TimeInterval)
    }

    var state: State = .await

    let jitterBuffer = JitterBuffer(capacity: 1024)

    override func viewDidLoad() {
        super.viewDidLoad()

        setupScene()

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        sceneView.addGestureRecognizer(tapGesture)

        setupGame()

    }

    // MARK: - GameKit

    var host: GKPlayer?
    var localPlayer: GKLocalPlayer!
    var match: GKMatch?

    func setupGame() {
        localPlayer = GKLocalPlayer.localPlayer()
        localPlayer.authenticateHandler = { (viewController, error) in
            if error == nil {
                if let viewController = viewController,
                    let delegate = UIApplication.shared.delegate,
                    let window = delegate.window,
                    let rootViewController = window?.rootViewController {
                    rootViewController.present(viewController, animated: true) { () in
                        print("Completed Authentication")
                    }
                } else {
                    print("Auth success; sending match request")
                    let matchRequest = GKMatchRequest()
                    matchRequest.minPlayers = 2
                    GKMatchmaker.shared().findMatch(for: matchRequest) { (match, error) in
                        if let match = match {
                            print("Found match", match)
                            self.match = match
                            match.delegate = self
                        } else {
                            print("Error finding match", error)
                        }
                    }
                }
            }
        }
    }

    func match(_ match: GKMatch, didFailWithError error: Error?) {
        print("Match failure", error)
    }

    func match(_ match: GKMatch, player: GKPlayer, didChange state: GKPlayerConnectionState) {
        print(match)
        switch state {
        case .stateUnknown:
            print("player", player, "unknown")
        case .stateDisconnected:
            print("player", player, "disconnected")
        case .stateConnected:
            print("expectedplayercount", match.expectedPlayerCount)
            if match.expectedPlayerCount == 0 { // Enough players have joined the match, let's play!
                // Deterministically choose a host. Don't use `chooseBestHostingPlayer` because it
                // takes too long.
                let playersSorted = (match.players + [self.localPlayer]).sorted { (lhs, rhs) in
                    lhs.playerID! < rhs.playerID!
                }
                self.host = playersSorted.first
                self.state = .joinedMatch
//                match.chooseBestHostingPlayer { best in
//                    if let player = best {
//                        print("found best")
//                        self.host = best
//                    } else {
//                        print("error")
//                    }
//                }
            }
        }
    }

    // Monotonically increasing clock; basically this is the frame count.
    func sequence(at currentTime: TimeInterval) -> Int? {
        switch state {
        case let .playing(startTime):
            let deltaTime = currentTime - startTime
            return Int(deltaTime * 60)
        default: return nil
        }
    }

    // MARK: - Multiplayer Networking

    /**
     * In order to keep clocks synchronized, the host transitions to the .playing state as soon
     * as it has joined a GameCenter match, noting its local time. Other players transition to the
     * .playing state when they receive the first message from the host. This prevents the non-host
     * players from having a clock far-ahead of the host, and thus ignoring all updates.
     *
     */

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        renderer.isPlaying = true
        switch state {
        case .joinedMatch:
            if localPlayer == host {
                state = .playing(Date.timeIntervalSinceReferenceDate)
            }
        case .await: ()
        case .playing(_):
            let sequence = self.sequence(at: Date.timeIntervalSinceReferenceDate)!
            DispatchQueue.main.async {
                self.sequenceLabel.text = "\(sequence)"
            }
            // The host broadcasts updates,
            if localPlayer == host {
                let packet = sceneView.scene!.packet(sequence: sequence)
                try! match!.sendData(toAllPlayers: packet.data, with: .unreliable)
            } else { // and other players just listen (for now).
                DispatchQueue.main.async {
                    if let packet = self.jitterBuffer[sequence] {
                        self.sceneView.scene!.apply(packet: packet)
                    }
                }
            }
        }
    }

    /**
     * Only non-host players receive updates for now.
     */
    func match(_ match: GKMatch, didReceive data: Data, fromRemotePlayer player: GKPlayer) {
        DispatchQueue.main.async {
            switch self.state {
            case .playing(_):
                if let packet = Packet(dataWrapper: DataWrapper(data)) {
                    self.jitterBuffer.push(packet)
                }
            case .joinedMatch:
                if self.localPlayer != self.host {
                    self.state = .playing(Date.timeIntervalSinceReferenceDate)
                    if let packet = Packet(dataWrapper: DataWrapper(data)) {
                        self.jitterBuffer.push(packet)
                    }
                }
            default:
                fatalError("Invalid state to receive data")
            }
        }
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
        node.register()
        sceneView.scene?.rootNode.addChildNode(node)
    }

    // MARK: - Scene gunk

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

        sceneView.scene = scene
        sceneView.allowsCameraControl = true
        sceneView.showsStatistics = true
        sceneView.backgroundColor = UIColor.black

        sceneView.delegate = self
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
