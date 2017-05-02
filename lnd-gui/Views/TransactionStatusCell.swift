//
//  TransactionStatusCell.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 5/1/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Cocoa

/** Transaction Status Cell
 */
class TransactionStatusCell: NSTableCellView {
  // MARK: - @IBOutlets
  
  /** Status indicator
   */
  @IBOutlet weak var statusBox: NSBox?
  
  // MARK: - Properties
  
  /** Transaction
   */
  var transaction: Transaction? { didSet { updateStatusBox() } }
  
  // MARK: - View

  /** Update the status box
   */
  private func updateStatusBox() {
    let isConfirmed = transaction?.confirmed == true
    
    statusBox?.fillColor = isConfirmed ? .selectedControlColor : .controlColor
    statusBox?.borderColor = isConfirmed ? .alternateSelectedControlColor : .controlShadowColor
  }
}
