//
//  TransactionHash.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 4/15/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Foundation

/** Transaction hash, also known as transaction id.
 */
struct TransactionHash {
  /** Create hash
   */
  init(from hexEncoded: HexEncodedData) throws {
    value = try hexEncoded.asDataFromHexEncoding()
  }
  
  /** Raw value
   */
  private let value: Data
}
