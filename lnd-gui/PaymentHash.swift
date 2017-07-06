//
//  PaymentHash.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 5/2/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Foundation

/** Lightning payment hash, also known as rhash. This is used as the identifier for a lightning transaction.
 
  For invoices, knowledge of the payment hash preimage represents payment in full.
 */
struct PaymentHash: DataValueBacked {
  /** Create from hex encoded string
   */
  init(from hexEncodedString: HexEncodedData) throws {
    value = try hexEncodedString.asDataFromHexEncoding()
  }
  
  /** Raw key value
   */
  let value: Data
}
