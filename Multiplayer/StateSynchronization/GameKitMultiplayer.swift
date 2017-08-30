import Foundation
import GameKit

class GameKitMultiplayer: NSObject, GKMatchDelegate {
    let localState = StateSynchronizer()
    let remoteState = StateSynchronizer()
    let sendPeriod = 1
    let inputInterpreter: InputInterpreter

    enum State {
        case waitingForLogin
        case loggedIn
        case foundMatch(GKMatch)
        case sending(GKMatch, host: GKPlayer, localStartTime: TimeInterval)
        case sendingAndReceiving(GKMatch, host: GKPlayer, localStartTime: TimeInterval, remoteStartTime: TimeInterval)
    }

    var state: State = .waitingForLogin

    // MARK: - GameKit

    init(inputInterpreter: InputInterpreter) {
        self.inputInterpreter = inputInterpreter
    }

    func login(andThen: @escaping () -> ()) {
        let localPlayer = GKLocalPlayer.localPlayer()
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
                    DispatchQueue.main.async {
                        self.state = .loggedIn
                        andThen()
                    }
                }
            }
        }
    }

    func sendMatchRequest(referenceNode: SCNNode) {
        switch state {
        case .loggedIn:
            self.localState.referenceNode = referenceNode
            self.remoteState.referenceNode = referenceNode
            let matchRequest = GKMatchRequest()
            matchRequest.minPlayers = 2
            GKMatchmaker.shared().findMatch(for: matchRequest) { (match, error) in
                if let match = match {
                    print("Found match", match)
                    self.state = .foundMatch(match)
                    match.delegate = self
                } else {
                    print("Error finding match", error)
                }
            }
//            self.state = .sendingAndReceiving(GKMatch(), host: GKLocalPlayer.localPlayer(), localStartTime: Date.timeIntervalSinceReferenceDate, remoteStartTime: Date.timeIntervalSinceReferenceDate)
        case .waitingForLogin:
            login { self.sendMatchRequest(referenceNode: referenceNode) }
        default: fatalError("Already in match")
        }
    }

    func match(_ match: GKMatch, didFailWithError error: Error?) {
        print("Match failure", error)
    }

    func match(_ match: GKMatch, player: GKPlayer, didChange state: GKPlayerConnectionState) {
        let localPlayer = GKLocalPlayer.localPlayer()
        switch state {
        case .stateUnknown:
            print("player", player, "unknown")
        case .stateDisconnected:
            print("player", player, "disconnected")
        case .stateConnected:
            switch self.state {
            case let .foundMatch(match_):
                print("player connected:", player)
                if match.expectedPlayerCount == 0 { // Enough players have joined the match, let's play!
                    // Deterministically choose a host. Don't use `chooseBestHostingPlayer` because it
                    // takes too long.
                    let playersSorted = (match.players + [localPlayer]).sorted { (lhs, rhs) in
                        lhs.playerID! < rhs.playerID!
                    }
                    let host = playersSorted.first!
                    DispatchQueue.main.async {
                        self.state = .sending(match_, host: host, localStartTime: Date.timeIntervalSinceReferenceDate)
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
            default:
                fatalError("Connection change in invalid state")
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
    var count = 0

    func renderedFrame(updateAtTime time: TimeInterval, of scene: SCNScene) {
        count += 1
        switch state {
        case .waitingForLogin, .loggedIn, .foundMatch(_):
            let localSequence = self.sequence(at: Date.timeIntervalSinceReferenceDate, from: Date.timeIntervalSinceReferenceDate)
            ()
            _ = localState.packet(at: localSequence)
        case let .sending(match, _, localStartTime):
            let localSequence = self.sequence(at: Date.timeIntervalSinceReferenceDate, from: localStartTime)
            let packet = localState.packet(at: localSequence)
            if count % sendPeriod == 0 {
                try! match.sendData(toAllPlayers: packet.data, with: .unreliable)
            }
        case let .sendingAndReceiving(match, _, localStartTime, remoteStartTime):
            let localSequence = self.sequence(at: Date.timeIntervalSinceReferenceDate, from: localStartTime)
            let packet = localState.packet(at: localSequence)
            if count % sendPeriod == 0 {
                try! match.sendData(toAllPlayers: packet.data, with: .unreliable)
            }

            let remoteSequence = self.sequence(at: Date.timeIntervalSinceReferenceDate, from: remoteStartTime)
            DispatchQueue.main.async {
                if let packet = self.remoteState.jitterBuffer[remoteSequence] {
                    self.remoteState.apply(packet: packet, to: scene, with: self.inputInterpreter)
                }
            }
        }
    }

    func match(_ match: GKMatch, didReceive data: Data, fromRemotePlayer player: GKPlayer) {
        DispatchQueue.main.async {
            switch self.state {
            case .sendingAndReceiving(_, _, _, _):
                if let packet = Packet(dataWrapper: DataWrapper(data)) {
                    self.remoteState.jitterBuffer.push(packet)
                }
            case let .sending(match, host, localStartTime):
                let remoteStartTime = Date.timeIntervalSinceReferenceDate
                DispatchQueue.main.async {
                    self.state = .sendingAndReceiving(match, host: host, localStartTime: localStartTime, remoteStartTime: remoteStartTime)
                    if let packet = Packet(dataWrapper: DataWrapper(data)) {
                        self.remoteState.jitterBuffer.push(packet)
                    }
                }
            default:
                fatalError("Invalid state to receive data")
            }
        }
    }

}
