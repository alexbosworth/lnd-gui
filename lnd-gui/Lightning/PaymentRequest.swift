//
//  PaymentRequest.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 5/9/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Foundation

struct PaymentRequest: JsonInitialized {
  let destination: PublicKey
  let id: PaymentHash
  let paymentRequest: String
  let tokens: Tokens
  
  enum JsonAttribute: String {
    case destination
    case id
    case tokens
    
    var asKey: String { return rawValue }
  }
  
  enum ParseJsonFailure: Error {
    case expectedPaymentRequestId
    case expectedPublicKey
    case expectedTokens
  }
  
  init(from data: Data?, paymentRequest: String) throws {
    self.paymentRequest = paymentRequest
    
    let json = try type(of: self).jsonDictionaryFromData(data)
    
    guard let hexEncodedDestinationPublicKey = json[JsonAttribute.destination.asKey] as? HexEncodedData else {
      throw ParseJsonFailure.expectedPublicKey
    }
    
    destination = try PublicKey(from: hexEncodedDestinationPublicKey)
    
    guard let paymentRequestId = json[JsonAttribute.id.asKey] as? HexEncodedData else {
      throw ParseJsonFailure.expectedPaymentRequestId
    }
    
    id = try PaymentHash(from: paymentRequestId)
    
    guard let amount = json[JsonAttribute.tokens.asKey] as? NSNumber else { throw ParseJsonFailure.expectedTokens }
    
    tokens = amount.tokensValue
  }
}
