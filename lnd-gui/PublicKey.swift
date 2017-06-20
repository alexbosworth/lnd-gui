//
//  PublicKey.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 4/15/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Foundation

protocol DataValueBacked {
  var value: Data { get }
}

extension DataValueBacked {
  /** Hex encoded
   */
  var hexEncoded: String { return value.asHexString }
}

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
