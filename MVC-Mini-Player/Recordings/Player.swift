import Foundation
import AVFoundation

class Player: NSObject, AVAudioPlayerDelegate {
	private(set) var audioPlayer: AVAudioPlayer!
	private var timer: Timer?
	private var update: (State) -> ()
	
	enum PlaybackState {
		case playing
		case paused
		case stopped
	}
	
	enum State {
		case notLoaded
		case loaded(playback: PlaybackState, duration: TimeInterval, progress: TimeInterval)
	}
	
	private(set) var state: State = .notLoaded
	
	init(url: URL, update: @escaping (State) -> ()) {
		self.update = update
		super.init()
		
		do {
			try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayAndRecord)
			try AVAudioSession.sharedInstance().setActive(true)
		} catch {
			update(.notLoaded)
			return
		}

		guard let player = try? AVAudioPlayer(contentsOf: url) else {
			update(.notLoaded)
			return
			
		}
		audioPlayer = player
		notify(.stopped)
		audioPlayer.delegate = self
	}
	
	func notify(_ playbackState: PlaybackState) {
		state = .loaded(playback: playbackState, duration: audioPlayer.duration, progress: audioPlayer.currentTime)
		update(state)
	}
	
	func togglePlay() {
		if audioPlayer.isPlaying {
			audioPlayer.pause()
			timer?.invalidate()
			timer = nil
			notify(.paused)
		} else {
			audioPlayer.play()
			if let t = timer {
				t.invalidate()
			}
			timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
				self?.notify(.playing)
			}
			notify(.playing)
		}
	}
	
	func setProgress(_ time: TimeInterval) {
		audioPlayer.currentTime = time
		guard case let .loaded(playbackState, _, _) = state else { return }
		notify(playbackState)
	}

	func audioPlayerDidFinishPlaying(_ pl: AVAudioPlayer, successfully flag: Bool) {
		timer?.invalidate()
		timer = nil
		notify(.stopped)
	}
	
	deinit {
		timer?.invalidate()
	}
}
