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
struct LightningInvoice {
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
  let paymentRequest: String?
  
  /** Invoice settled state
   */
  let isConfirmed: Bool
  
  /** Token amount
   */
  let tokens: Tokens
  
  /** JsonParseError defines errors encountered when parsing a JSON encoded invoice.
   */
  enum JsonParseError: Error {
    case invalidJson
    case missing(JsonAttribute)
  }

  /** Create from json data
   */
  init(from data: Data) throws {
    guard let json = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] else {
      throw JsonParseError.invalidJson
    }
    
    self = try type(of: self).init(from: json)
  }

  enum JsonAttribute: JsonAttributeName {
    case address
    case confirmed
    case createdAt = "created_at"
    case id
    case memo
    case paymentRequest = "payment_request"
    case tokens
    
    var asKey: JsonAttributeName { return rawValue }
  }
  
  /** init creates an invoice from a JSON dictionary.
   */
  init(from json: [String: Any]) throws {
    guard let invoiceId = json[JsonAttribute.id.asKey] as? String else {
      throw JsonParseError.missing(.id)
    }
    
    if let invoicePaymentRequest = json[JsonAttribute.paymentRequest.asKey] as? String {
      self.paymentRequest = invoicePaymentRequest
    } else {
      self.paymentRequest = nil
    }

    guard let tokens = (json[JsonAttribute.tokens.asKey] as? NSNumber)?.tokensValue else {
      throw JsonParseError.missing(.tokens)
    }
    
    chainAddress = json[JsonAttribute.address.asKey] as? String
    isConfirmed = (json[JsonAttribute.confirmed.asKey] as? Bool ?? false) as Bool
    id = invoiceId
    memo = json[JsonAttribute.memo.asKey] as? String
    self.tokens = tokens
    
    let createdAtString = json[JsonAttribute.createdAt.asKey] as? String
    
    if let str = createdAtString { createdAt = DateFormatter().date(fromIso8601: str) } else { createdAt = nil }
  }
  
  enum Failure: Error {
    case expectedReceivedPayment
  }
}

extension DateFormatter {
  func date(fromIso8601 string: String) -> Date? {
    locale = Locale(identifier: "en_US_POSIX")
    dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"

    return date(from: string)
  }
}
