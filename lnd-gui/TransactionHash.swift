//
//  TransactionHash.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 4/15/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Foundation

/** Transaction hash, also known as transaction id. This is the double SHA256 hash of the serialized transaction.

 Transaction hashes are used as identifiers for transactions when constructing new transactions that spend the unspent
 outputs of past transactions.
 */
struct TransactionHash: DataValueBacked {
  /** Create hash
   */
  init(from hexEncoded: HexEncodedData) throws {
    value = try hexEncoded.asDataFromHexEncoding()
  }
  
  /** Raw value
   */
  let value: Data
}
