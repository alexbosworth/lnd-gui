//
//  MainWindowController.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 3/5/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Cocoa

/** Main window controller, the controller that manages the containing main window.
 */
class MainWindowController: NSWindowController {
  /** Dimension defines sizes in the main window controller.
   */
  enum Dimension {
    static let bottomBarHeight: CGFloat = 24
  }
  
  /** Window did load, called when the window initializes.
   */
  override func windowDidLoad() {
    super.windowDidLoad()
    
    window?.setContentBorderThickness(Dimension.bottomBarHeight, for: .minY)

    window?.title = NSLocalizedString("Wallet", comment: "Wallet window title")
  }
}
