//
//  PaymentRequest.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 5/9/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Foundation

typealias SerializedPaymentRequest = String

/** Lightning Network payment request
 */
struct LightningPayment: JsonInitialized {
  let createdAt: Date?
  let destination: PublicKey
  let id: PaymentHash
  let isConfirmed: Bool?
  let serializedPaymentRequest: SerializedPaymentRequest?
  let tokens: Tokens
  
  enum JsonAttribute: JsonAttributeName {
    case confirmed
    case createdAt = "created_at"
    case destination
    case id
    case tokens
    
    var asKey: String { return rawValue }
  }
  
  enum ParseJsonFailure: Error {
    case missing(JsonAttribute)
  }

  init(from json: JsonDictionary, paymentRequest: SerializedPaymentRequest? = nil) throws {
    let createdAtString = json[JsonAttribute.createdAt.asKey] as? String
    
    if let str = createdAtString { createdAt = DateFormatter().date(fromIso8601: str) } else { createdAt = nil }
    
    guard let confirmed = json[JsonAttribute.confirmed.asKey] as? Bool else {
      throw ParseJsonFailure.missing(.confirmed)
    }
    
    isConfirmed = confirmed
    
    guard let hexEncodedDestinationPublicKey = json[JsonAttribute.destination.asKey] as? HexEncodedData else {
      throw ParseJsonFailure.missing(.destination)
    }
    
    destination = try PublicKey(from: hexEncodedDestinationPublicKey)
    
    guard let paymentRequestId = json[JsonAttribute.id.asKey] as? HexEncodedData else {
      throw ParseJsonFailure.missing(.id)
    }
    
    id = try PaymentHash(from: paymentRequestId)
    
    serializedPaymentRequest = paymentRequest
    
    guard let amount = json[JsonAttribute.tokens.asKey] as? NSNumber else { throw ParseJsonFailure.missing(.tokens) }
    
    tokens = amount.tokensValue
  }
  
  init(from data: Data?, paymentRequest payReq: SerializedPaymentRequest) throws {
    self = try type(of: self).init(from: try type(of: self).jsonDictionaryFromData(data), paymentRequest: payReq)
  }
}
