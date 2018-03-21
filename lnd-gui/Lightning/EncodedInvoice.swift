//
//  EncodedInvoice.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 5/9/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Foundation

typealias SerializedInvoice = String

/** Lightning Network payment request
 */
struct LightningPayment: JsonInitialized {
  let createdAt: Date?
  let destination: PublicKey?
  let id: PaymentHash
  let isConfirmed: Bool?
  let serializedInvoice: SerializedInvoice?
  let tokens: Tokens
  
  enum JsonAttribute: JsonAttributeName {
    case createdAt = "created_at"
    case destination
    case id
    case isConfirmed = "is_confirmed"
    case tokens
    
    var asKey: String { return rawValue }
  }
  
  enum ParseJsonFailure: Error {
    case missing(JsonAttribute)

    var localizedDescription: String {
      switch self {
      case .missing(let attr):
        return "Expected Attribute Not Found: \(attr.asKey)"
      }
    }
  }

  init(from json: JsonDictionary, invoice: SerializedInvoice? = nil) throws {
    let createdAtString = json[JsonAttribute.createdAt.asKey] as? String
    
    if let str = createdAtString { createdAt = DateFormatter().date(fromIso8601: str) } else { createdAt = nil }
    
    isConfirmed = json[JsonAttribute.isConfirmed.asKey] as? Bool
    
    if let hexEncodedDestinationPublicKey = json[JsonAttribute.destination.asKey] as? HexEncodedData {
      destination = try PublicKey(from: hexEncodedDestinationPublicKey)
    } else {
      destination = nil
    }
    
    guard let invoiceId = json[JsonAttribute.id.asKey] as? HexEncodedData else {
      throw ParseJsonFailure.missing(.id)
    }
    
    id = try PaymentHash(from: invoiceId)
    
    serializedInvoice = invoice
    
    guard let amount = json[JsonAttribute.tokens.asKey] as? NSNumber else { throw ParseJsonFailure.missing(.tokens) }
    
    tokens = amount.tokensValue
  }
  
  init(from data: Data?, invoice: SerializedInvoice) throws {
    self = try type(of: self).init(from: try type(of: self).jsonDictionaryFromData(data), invoice: invoice)
  }
}
