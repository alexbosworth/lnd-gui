//
//  TransactionViewController.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 5/14/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Cocoa

class TransactionViewController: NSViewController {
  // MARK: - @IBOutlets
  
  // MARK: - Properties
  
  var transaction: Transaction?
}

extension TransactionViewController {
  func updatedTransaction() {
    guard let transaction = transaction else { return print("ERROR", "expected transaction") }
    
    
  }
}
