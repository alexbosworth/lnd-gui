//
//  PaymentRequest.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 5/9/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Foundation

typealias SerializedPaymentRequest = String

/** Lightning Network payment request that
 */
struct PaymentRequest: JsonInitialized {
  let destination: PublicKey
  let id: PaymentHash
  let paymentRequest: SerializedPaymentRequest
  let tokens: Tokens
  
  enum JsonAttribute: JsonAttributeName {
    case destination, id, tokens
    
    var asKey: String { return rawValue }
  }
  
  enum ParseJsonFailure: Error {
    case missing(JsonAttribute)
  }
  
  init(from data: Data?, paymentRequest: String) throws {
    self.paymentRequest = paymentRequest
    
    let json = try type(of: self).jsonDictionaryFromData(data)
    
    guard let hexEncodedDestinationPublicKey = json[JsonAttribute.destination.asKey] as? HexEncodedData else {
      throw ParseJsonFailure.missing(.destination)
    }
    
    destination = try PublicKey(from: hexEncodedDestinationPublicKey)
    
    guard let paymentRequestId = json[JsonAttribute.id.asKey] as? HexEncodedData else {
      throw ParseJsonFailure.missing(.id)
    }
    
    id = try PaymentHash(from: paymentRequestId)
    
    guard let amount = json[JsonAttribute.tokens.asKey] as? NSNumber else { throw ParseJsonFailure.missing(.tokens) }
    
    tokens = amount.tokensValue
  }
}
