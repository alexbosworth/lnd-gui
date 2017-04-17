//
//  PublicKey.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 4/15/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Foundation

struct PublicKey {
  init(from hexEncodedString: String) {
    value = hexEncodedString
  }
  
  private let value: String
  
  var hexEncoded: String { return value }
}
