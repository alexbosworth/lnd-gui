//
//  MainTabViewController.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 3/5/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Cocoa

typealias StoryboardIdentifier = String

/** MainTabViewController is the overall tab controller.
 */
class MainTabViewController: NSTabViewController {
  // MARK: - Properties
  
  /** updateBalance closure triggers a balance update
   */
  var updateBalance: (() -> ())?
}

// MARK: - Failures
extension MainTabViewController {
  /** Failure defines an encountered error.
   */
  enum Failure: String, Error {
    case expectedTab
    case expectedViewController
  }
}

// MARK: - Navigation
extension MainTabViewController {
  /** Tab defines a tab in the tab view controller.
   */
  enum Tab {
    case send

    /** storyboardIdentifier returns the identifier used in the storyboard for the tab.
     */
    var storyboardIdentifier: StoryboardIdentifier {
      switch self {
      case .send:
        return "SendTab"
      }
    }
  }
}

// MARK: - NSViewController
extension MainTabViewController {
  /** viewDidLoad triggers when the view loads initially
   */
  override func viewDidLoad() {
    super.viewDidLoad()
    
    let sendTabIndex = tabView.indexOfTabViewItem(withIdentifier: Tab.send.storyboardIdentifier)
    
    guard sendTabIndex < tabViewItems.endIndex && sendTabIndex >= tabViewItems.startIndex else {
      return print(Failure.expectedTab)
    }
    
    let sendTab = tabViewItems[sendTabIndex]
    
    guard let sendViewController = sendTab.viewController as? SendViewController else {
      return print(Failure.expectedViewController)
    }
    
    sendViewController.updateBalance = { [weak self] in self?.updateBalance?() }
  }
}
