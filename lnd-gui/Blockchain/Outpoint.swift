//
//  Outpoint.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 4/15/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Foundation

struct Outpoint {
  let transactionId: TransactionHash
  let vout: UInt32
}
