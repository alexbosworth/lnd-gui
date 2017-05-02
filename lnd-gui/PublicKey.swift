//
//  PublicKey.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 4/15/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Foundation

/** ECDSA Public Key
 */
struct PublicKey {
  /** Create from hex encoded string
   */
  init(from hexEncodedString: HexEncodedData) throws {
    value = try hexEncodedString.asDataFromHexEncoding()
  }
  
  /** Raw key value
   */
  private let value: Data
  
  /** Hex encoded
   */
  var hexEncoded: String { return value.asHexString }
}
