//
//  MainWindowController.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 3/5/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Cocoa

/** MainWindowController is the controller that manages the containing main window.
 */
class MainWindowController: NSWindowController {
  /** Dimension 
   */
  enum Dimension {
    static let bottomBarHeight: CGFloat = 24
  }
  
  /** windowDidLoad method is called when the window initializes.
   */
  override func windowDidLoad() {
    super.windowDidLoad()
    
    window?.setContentBorderThickness(Dimension.bottomBarHeight, for: .minY)
    
    window?.title = String()
  }
}
