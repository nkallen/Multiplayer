import Foundation
import UIKit
import ReplayKit

class NonRecordingWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let resultView = super.hitTest(point, with: event)
        if resultView == self.rootViewController!.view {
            return nil
        }

        return resultView
    }

    func present(_ viewControllerToPresent: UIViewController, animated: Bool, completion: (() -> Void)? = nil) {
        rootViewController?.present(viewControllerToPresent, animated: animated, completion: completion)
    }
}

class ScreenRecordingManager: NSObject, RPPreviewViewControllerDelegate {
    var isRecording = false
    var nonRecordingWindow: NonRecordingWindow!

    init(frame: CGRect, view: UIView) {
        nonRecordingWindow = NonRecordingWindow(frame: frame)
        nonRecordingWindow.rootViewController = UIViewController()
        nonRecordingWindow.rootViewController?.view = view
        nonRecordingWindow.makeKeyAndVisible()
    }

    func toggleRecording() {
        let recorder = RPScreenRecorder.shared()

        if isRecording {
            recorder.stopRecording { (previewController, error) in
                self.isRecording = false

                guard error == nil else {
                    return

                }
                previewController?.previewControllerDelegate = self

                let alertController = UIAlertController(title: "Recording", message: "Do you wish to keep your recording?", preferredStyle: .alert)
                let discardAction = UIAlertAction(title: "Discard", style: .default) { (action: UIAlertAction) in
                    recorder.discardRecording {

                    }
                }

                let viewAction = UIAlertAction(title: "Preview", style: .default) { (action) in
                    self.nonRecordingWindow.present(previewController!, animated: true, completion: nil)
                }

                alertController.addAction(discardAction)
                alertController.addAction(viewAction)

                self.nonRecordingWindow.present(alertController, animated: true, completion: nil)
            }
        } else {
            if recorder.isAvailable {
                recorder.startRecording { (error) in
                    guard error == nil else {
                        print("error", error)
                        return
                    }
                    print("setting is recording true")
                    self.isRecording = true
                }
            } else {
                // Display UI for recording being unavailable
            }
        }
    }


    // MARK: - RPPreviewViewControllerDelegate

    func previewControllerDidFinish(_ previewController: RPPreviewViewController) {
        previewController.dismiss(animated: true)
    }
}
