//
//  TransactionHash.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 4/15/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Foundation

struct TransactionHash {
  init(from hexEncoded: String) {
    value = hexEncoded
  }
  
  private let value: String
}
