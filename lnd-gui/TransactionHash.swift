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
  /** Create hash from hex encoded data string
   */
  init(from hexEncoded: HexEncodedData) throws {
    value = try hexEncoded.asDataFromHexEncoding()
  }
  
  /** Create has from hex encoded data string, using internal byte order
   */
  init(fromInternal hex: HexEncodedData) throws {
    let txOutpointHashChars = Array(hex.characters)
    
    let reverseOrderBytes: [[Character]] = stride(from: Int(), to: txOutpointHashChars.count, by: 2)
      .map { Array(Array(hex.characters)[$0..<min($0 + 2, Array(hex.characters).count)]) }

    let normalOrderBytes: String = reverseOrderBytes.reversed().map { String($0) }.joined()
    
    try self.init(from: normalOrderBytes)
  }
  
  /** Raw value
   */
  let value: Data
}
