//
//  Outpoint.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 4/15/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Foundation

/** Vout represents an output index number
 */
typealias Vout = UInt32

/** Transaction outpoint
 */
struct Outpoint {
  /** Transaction hash
   */
  let transactionId: TransactionHash
  
  /** Transaction output index
   */
  let vout: Vout
}
