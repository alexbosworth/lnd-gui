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
  
  /** Description is the description of the invoice.
   */
  let description: String?

  /** id is the rhash identifier of the invoice.
   */
  let id: String
  
  /** invoice is the bech32 encoding of the invoice
   */
  let invoice: String?
  
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

    var localizedDescription: String {
      switch self {
      case .invalidJson:
        return "Expected valid JSON"
        
      case .missing(let attr):
        return "Expected Attribute Not Found: \(attr.asKey)"
      }
    }
  }

  /** Create from json data
   */
  init(from data: Data) throws {
    guard let json = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? JsonDictionary else {
      throw JsonParseError.invalidJson
    }
    
    self = try type(of: self).init(from: json)
  }

  enum JsonAttribute: JsonAttributeName {
    case chainAddress = "chain_address"
    case createdAt = "created_at"
    case description
    case id
    case isConfirmed = "is_confirmed"
    case invoice
    case tokens

    /** JSON Key
     */
    var asKey: JsonAttributeName { return rawValue }
  }
  
  /** init creates an invoice from a JSON dictionary.
   */
  init(from json: JsonDictionary) throws {
    guard let invoiceId = json[JsonAttribute.id.asKey] as? String else {
      throw JsonParseError.missing(.id)
    }
    
    if let invoiceInvoice = json[JsonAttribute.invoice.asKey] as? String {
      self.invoice = invoiceInvoice
    } else {
      self.invoice = nil
    }

    guard let tokens = (json[JsonAttribute.tokens.asKey] as? NSNumber)?.tokensValue else {
      throw JsonParseError.missing(.tokens)
    }
    
    chainAddress = json[JsonAttribute.chainAddress.asKey] as? String
    description = json[JsonAttribute.description.asKey] as? String
    id = invoiceId
    isConfirmed = (json[JsonAttribute.isConfirmed.asKey] as? Bool ?? false) as Bool
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
