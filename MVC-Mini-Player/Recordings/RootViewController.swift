//
//  RootViewController.swift
//  Recordings
//
//  Created by Fu Yuan on 22/07/18.
//

import UIKit

final class RootViewController: UIViewController, UISplitViewControllerDelegate {
	@IBOutlet weak var heightConstraint: NSLayoutConstraint!
	@IBOutlet weak var bottomConstraint: NSLayoutConstraint!
	
	var miniPlayerVisible: Bool = true {
		didSet {
			bottomConstraint.constant = miniPlayerVisible ? 0 : -heightConstraint.constant
		}
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		miniPlayerVisible = false
	}
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		if segue.identifier == "embedSplitViewController" {
			let splitViewController = segue.destination as! UISplitViewController
			splitViewController.delegate = self
			splitViewController.preferredDisplayMode = .allVisible
		}
	}
	
	@IBAction func unwindFromPlayer(segue: UIStoryboardSegue) {
		miniPlayerVisible = SharedPlayer.shared.isPlaying
	}
	
	func splitViewController(_ splitViewController: UISplitViewController, collapseSecondary secondaryViewController: UIViewController, onto primaryViewController: UIViewController) -> Bool {
		guard let topAsDetailController = (secondaryViewController as? UINavigationController)?.topViewController as? PlayViewController else { return false }
		if topAsDetailController.recording == nil {
			// Don't include an empty player in the navigation stack when collapsed
			return true
		}
		return false
	}
}
