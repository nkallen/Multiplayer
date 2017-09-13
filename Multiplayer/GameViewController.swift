import UIKit
import QuartzCore
import SceneKit
import GameKit

class GameViewController: UIViewController {
    var screenRecordingManager: ScreenRecordingManager!

    @IBOutlet weak var sceneView: SceneView!
    @IBOutlet weak var sequenceLabel: UILabel!
    @IBOutlet var nonRecordingView: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()

//        _ = multiplayer.localState.register(cameraNode, priority: 1) { registered in
//            self.multiplayer.localState.input(.create(.pov, id: registered.id))
//        }


    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        screenRecordingManager = ScreenRecordingManager(frame: view.frame, view: nonRecordingView)
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
