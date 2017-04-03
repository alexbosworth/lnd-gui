//
//  Invoice.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 4/2/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Foundation

/** Payment invoice
 */
struct Invoice {
  /** id is the rhash identifier of the invoice.
   */
  let id: String
  
  /** paymentRequest is the full encoding of the payment request.
   */
  let paymentRequest: String
  
  /** JsonParseError defines errors encountered when parsing a JSON encoded invoice.
   */
  enum JsonParseError: String, Error {
    case expectedId
    case expectedPaymentRequest
  }
  
  /** init creates an invoice from a JSON dictionary.
   */
  init(from json: [String: Any]) throws {
    guard let id = json["id"] as? String else { throw JsonParseError.expectedId }
    
    guard let paymentRequest = json["payment_request"] as? String else { throw JsonParseError.expectedPaymentRequest }
    
    self.id = id
    self.paymentRequest = paymentRequest
  }
}
