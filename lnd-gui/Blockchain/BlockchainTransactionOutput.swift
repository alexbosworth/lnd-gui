//
//  BlockchainTransactionOutput.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 7/8/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Foundation

/** Blockchain transaction output
 */
struct BlockchainTransactionOutput {
  let address: String
  let tokens: Tokens
  
  init(address: String, tokens: Tokens) {
    self.address = address
    self.tokens = tokens
  }
  
  enum Failure: Error {
    case expectedAddress
    case expectedTokens
  }
  
  init(from json: [String: Any]) throws {
    enum JsonAttribute: String {
      case address, tokens
      
      var key: String { return rawValue }
    }
    
    guard let address = json[JsonAttribute.address.key] as? String else { throw Failure.expectedAddress }
    
    guard let tokens = json[JsonAttribute.tokens.key] as? NSNumber else { throw Failure.expectedTokens }
    
    self.address = address
    self.tokens = tokens.tokensValue
  }
}
