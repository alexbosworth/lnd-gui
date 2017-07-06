//
//  PublicKey.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 4/15/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Foundation

/** ECDSA public key
 */
struct PublicKey: DataValueBacked {
  /** Create from hex encoded string
   */
  init(from hexEncodedString: HexEncodedData) throws {
    value = try hexEncodedString.asDataFromHexEncoding()
  }
  
  /** Raw key value
   */
  let value: Data
}
