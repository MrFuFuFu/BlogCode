import UIKit
import AVFoundation

final class SharedPlayer {
	static let shared = SharedPlayer()
	
	struct State {
		var duration: TimeInterval = 0
		var progress: TimeInterval = 0
	}
	
	var state = State() {
		didSet {
			notify()
		}
	}
	var audioPlayer: Player?
	var recording: Recording? {
		didSet {
			updateForChangedRecording()
		}
	}
	
	static let notification = Notification.Name(rawValue: "io.objc.SharedPlayerChanged")
	func notify() {
		NotificationCenter.default.post(name: SharedPlayer.notification, object: self)
	}
	
	func updateForChangedRecording() {
		if let r = recording, let url = r.fileURL {
			audioPlayer = Player(url: url) { [weak self] time in
				if let t = time {
					self?.state.progress = t
				} else {
					self?.state = State()
					self?.recording = nil
				}
			}
			
			if let ap = audioPlayer {
				state = State(duration: ap.duration, progress: 0)
			} else {
				state = State()
				recording = nil
			}
		} else {
			state = State()
			audioPlayer = nil
		}
	}
}

class PlayViewController: UIViewController, UITextFieldDelegate, AVAudioPlayerDelegate {
	@IBOutlet var nameTextField: UITextField!
	@IBOutlet var playButton: UIButton!
	@IBOutlet var progressLabel: UILabel!
	@IBOutlet var durationLabel: UILabel!
	@IBOutlet var progressSlider: UISlider!
	@IBOutlet var noRecordingLabel: UILabel!
	@IBOutlet var activeItemElements: UIView!
	
	var audioPlayer: Player? {
		return SharedPlayer.shared.audioPlayer
	}
	var recording: Recording? {
		get { return SharedPlayer.shared.recording }
		set { SharedPlayer.shared.recording = newValue }
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem
		navigationItem.leftItemsSupplementBackButton = true
		updateForChangedRecording()

		NotificationCenter.default.addObserver(self, selector: #selector(storeChanged(notification:)), name: Store.changedNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(playerChanged(notification:)), name: SharedPlayer.notification, object: nil)
	}

	@objc func storeChanged(notification: Notification) {
		guard let item = notification.object as? Item, item === recording else { return }
		updateForChangedRecording()
	}
	
	@objc func playerChanged(notification: Notification) {
		updateForChangedRecording()
	}
	
	func updateForChangedRecording() {
		if let r = recording{
			updateProgressDisplays(progress: SharedPlayer.shared.state.progress, duration: SharedPlayer.shared.state.duration)
			title = r.name
			nameTextField?.text = r.name
			activeItemElements?.isHidden = false
			noRecordingLabel?.isHidden = true
		} else {
			updateProgressDisplays(progress: 0, duration: 0)
			title = ""
			activeItemElements?.isHidden = true
			noRecordingLabel?.isHidden = false
		}
	}
	
	func updateProgressDisplays(progress: TimeInterval, duration: TimeInterval) {
		progressLabel?.text = timeString(progress)
		durationLabel?.text = timeString(duration)
		progressSlider?.maximumValue = Float(duration)
		progressSlider?.value = Float(progress)
		updatePlayButton()
	}
	
	func updatePlayButton() {
		if audioPlayer?.isPlaying == true {
			playButton?.setTitle(.pause, for: .normal)
		} else if audioPlayer?.isPaused == true {
			playButton?.setTitle(.resume, for: .normal)
		} else {
			playButton?.setTitle(.play, for: .normal)
		}
	}
	
	func textFieldDidEndEditing(_ textField: UITextField) {
		if let r = recording, let text = textField.text {
			r.setName(text)
			title = r.name
		}
	}
	
	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		textField.resignFirstResponder()
		return true
	}
	
	@IBAction func setProgress() {
		guard let s = progressSlider else { return }
		audioPlayer?.setProgress(TimeInterval(s.value))
	}
	
	@IBAction func play() {
		audioPlayer?.togglePlay()
		updatePlayButton()
	}
	
	// MARK: UIStateRestoring
	
	override func encodeRestorableState(with coder: NSCoder) {
		super.encodeRestorableState(with: coder)
		coder.encode(recording?.uuidPath, forKey: .uuidPathKey)
	}
	
	override func decodeRestorableState(with coder: NSCoder) {
		super.decodeRestorableState(with: coder)
		if let uuidPath = coder.decodeObject(forKey: .uuidPathKey) as? [UUID], let recording = Store.shared.item(atUUIDPath: uuidPath) as? Recording {
			self.recording = recording
		}
	}
}

fileprivate extension String {
	static let uuidPathKey = "uuidPath"
	
	static let pause = NSLocalizedString("Pause", comment: "")
	static let resume = NSLocalizedString("Resume playing", comment: "")
	static let play = NSLocalizedString("Play", comment: "")
}
