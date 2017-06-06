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
  /** Alternative address for receiving on chain
   */
  let chainAddress: String?
  
  /** Created at
   */
  let createdAt: Date?
  
  /** id is the rhash identifier of the invoice.
   */
  let id: String
  
  /** Memo is the description of the invoice.
   */
  let memo: String?
  
  /** paymentRequest is the full encoding of the payment request.
   */
  let paymentRequest: String
  
  /** Invoice settled state
   */
  let confirmed: Bool
  
  /** Token amount
   */
  let tokens: Tokens?
  
  /** JsonParseError defines errors encountered when parsing a JSON encoded invoice.
   */
  enum JsonParseError: String, Error {
    case expectedId
    case expectedJson
    case expectedPaymentRequest
  }

  /** Create from json data
   */
  init(from data: Data) throws {
    guard let json = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] else {
      throw JsonParseError.expectedJson
    }
    
    self = try type(of: self).init(from: json)
  }
  
  /** init creates an invoice from a JSON dictionary.
   */
  init(from json: [String: Any]) throws {
    guard let id = json["id"] as? String else { throw JsonParseError.expectedId }
    
    guard let paymentRequest = json["payment_request"] as? String else { throw JsonParseError.expectedPaymentRequest }
    
    self.chainAddress = json["address"] as? String
    self.confirmed = (json["confirmed"] as? Bool ?? false) as Bool
    self.id = id
    self.memo = json["memo"] as? String
    self.paymentRequest = paymentRequest
    self.tokens = (json["tokens"] as? NSNumber)?.tokensValue
    
    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
    
    let createdAtString = json["created_at"] as? String
    let createdAt: Date?
    
    if let str = createdAtString { createdAt = dateFormatter.date(from: str) } else { createdAt = nil }

    self.createdAt = createdAt
  }
  
  enum Failure: String, Error {
    case expectedReceivedPayment
  }
  
  init(from transaction: Transaction) throws {
    guard case .received(let invoice) = transaction.destination else {
      throw Failure.expectedReceivedPayment
    }
    
    self = invoice
  }
}
