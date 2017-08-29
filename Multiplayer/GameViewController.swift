import UIKit
import QuartzCore
import SceneKit
import GameKit

class GameViewController: UIViewController, GKLocalPlayerListener, GKMatchDelegate, SCNSceneRendererDelegate {
    var screenRecordingManager: ScreenRecordingManager!

    @IBOutlet weak var sceneView: SCNView!
    @IBOutlet weak var sequenceLabel: UILabel!
    @IBOutlet var nonRecordingView: UIView!

    let localState = StateSynchronizer()
    let remoteState = StateSynchronizer()

    enum State {
        case await
        case sending(TimeInterval)
        case sendingAndReceiving(TimeInterval, TimeInterval)
    }

    var state: State = .await

    override func viewDidLoad() {
        super.viewDidLoad()

        setupScene()

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        sceneView.addGestureRecognizer(tapGesture)

        setupGame()

    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        screenRecordingManager = ScreenRecordingManager(frame: view.frame, view: nonRecordingView)
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
        print("player", player, "match", match)
        switch state {
        case .stateUnknown:
            print("player", player, "unknown")
        case .stateDisconnected:
            print("player", player, "disconnected")
        case .stateConnected:
            if match.expectedPlayerCount == 0 { // Enough players have joined the match, let's play!
                // Deterministically choose a host. Don't use `chooseBestHostingPlayer` because it
                // takes too long.
                let playersSorted = (match.players + [self.localPlayer]).sorted { (lhs, rhs) in
                    lhs.playerID! < rhs.playerID!
                }
                self.host = playersSorted.first
                DispatchQueue.main.async {
                    self.state = .sending(Date.timeIntervalSinceReferenceDate)
                }
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
    func sequence(at currentTime: TimeInterval, from startTime: TimeInterval) -> Int {
        let deltaTime = currentTime - startTime
        return Int(deltaTime * 60)
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
        case .await: ()
        case let .sending(localStartTime):
            let localSequence = self.sequence(at: Date.timeIntervalSinceReferenceDate, from: localStartTime)
            let packet = localState.packet(at: localSequence)
            try! match!.sendData(toAllPlayers: packet.data, with: .unreliable)
        case let .sendingAndReceiving(localStartTime, remoteStartTime):
            let localSequence = self.sequence(at: Date.timeIntervalSinceReferenceDate, from: localStartTime)
            let packet = localState.packet(at: localSequence)
            try! match!.sendData(toAllPlayers: packet.data, with: .unreliable)

            let remoteSequence = self.sequence(at: Date.timeIntervalSinceReferenceDate, from: remoteStartTime)
            DispatchQueue.main.async {
                if let packet = self.remoteState.jitterBuffer[remoteSequence] {
                    self.remoteState.apply(packet: packet, to: self.sceneView.scene!)
                }

                self.sequenceLabel.text = "\(localSequence), \(remoteSequence)"
            }
        }
    }

    func match(_ match: GKMatch, didReceive data: Data, fromRemotePlayer player: GKPlayer) {
        DispatchQueue.main.async {
            switch self.state {
            case .sendingAndReceiving(_, _):
                if let packet = Packet(dataWrapper: DataWrapper(data)) {
                    self.remoteState.jitterBuffer.push(packet)
                }
            case let .sending(localStartTime):
                DispatchQueue.main.async {
                    self.state = .sendingAndReceiving(localStartTime, Date.timeIntervalSinceReferenceDate)
                    if let packet = Packet(dataWrapper: DataWrapper(data)) {
                        self.remoteState.jitterBuffer.push(packet)
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
        _ = localState.register(node)
        sceneView.scene?.rootNode.addChildNode(node)
    }

    // MARK: - Scene gunk

    func setupScene() {
        let scene = SCNScene(named: "art.scnassets/ship.scn")!

        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        scene.rootNode.addChildNode(cameraNode)
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 15)
        _ = localState.register(cameraNode)

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
