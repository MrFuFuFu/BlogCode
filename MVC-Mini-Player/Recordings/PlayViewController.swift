import UIKit
import AVFoundation

final class SharedPlayer {
	static let shared = SharedPlayer()
	
	var audioPlayer: Player?
	var recording: Recording? {
		didSet {
			updateForChangedRecording()
		}
	}
	
	var isPlaying: Bool {
		if case .loaded(.playing, _, _) = state {
			return true
		}
		return false
	}
	
	static let notification = Notification.Name(rawValue: "io.objc.SharedPlayerChanged")
	func notify() {
		NotificationCenter.default.post(name: SharedPlayer.notification, object: self)
	}
	
	var state: Player.State {
		return audioPlayer?.state ?? .notLoaded
	}
	
	func updateForChangedRecording() {
		if let r = recording, let url = r.fileURL {
			audioPlayer = Player(url: url) { [weak self] state in
				self?.notify()
			}
		} else {
			audioPlayer = nil
			notify()
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
	
	var sharedPlayer: SharedPlayer {
		return SharedPlayer.shared
	}
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
		updateDisplay()

		NotificationCenter.default.addObserver(self, selector: #selector(storeChanged(notification:)), name: Store.changedNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(playerChanged(notification:)), name: SharedPlayer.notification, object: nil)
	}

	@objc func storeChanged(notification: Notification) {
		guard let item = notification.object as? Item, item === recording else { return }
		updateDisplay()
	}
	
	@objc func playerChanged(notification: Notification) {
		updateDisplay()
	}
	
	func updateDisplay() {
		updateControls()
		if let r = sharedPlayer.recording {
			title = r.name
			nameTextField?.text = r.name
			activeItemElements?.isHidden = false
			noRecordingLabel?.isHidden = true
		} else {
			title = ""
			activeItemElements?.isHidden = true
			noRecordingLabel?.isHidden = false
		}
	}
	
	func updateControls() {
		progressLabel?.text = timeString(sharedPlayer.state.progress)
		durationLabel?.text = timeString(sharedPlayer.state.duration)
		progressSlider?.maximumValue = Float(sharedPlayer.state.duration)
		progressSlider?.value = Float(sharedPlayer.state.progress)
		playButton.setTitle(sharedPlayer.state.buttonTitle, for: .normal)
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

fileprivate extension Player.State {
	var progress: TimeInterval {
		switch self {
		case .notLoaded: return 0
		case let .loaded(_, _, p): return p
		}
	}
	
	var duration: TimeInterval {
		switch self {
		case .notLoaded: return 0
		case let .loaded(_, d, _): return d
		}
	}
	
	var buttonTitle: String {
		switch self {
		case .notLoaded: return ""
		case let .loaded(playback, _, _):
			switch playback {
			case .stopped: return .play
			case .playing: return .pause
			case .paused: return .resume
			}
		}
	}
}

fileprivate extension String {
	static let uuidPathKey = "uuidPath"
	
	static let pause = NSLocalizedString("Pause", comment: "")
	static let resume = NSLocalizedString("Resume playing", comment: "")
	static let play = NSLocalizedString("Play", comment: "")
}
