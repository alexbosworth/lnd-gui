//
//  BlockchainTransactionInput.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 7/8/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Foundation

/** Blockchain transaction input
 */
struct BlockchainTransactionInput {
  let transactionId: String
  let vout: Int
  
  init(transactionId: String, vout: Int) {
    self.transactionId = transactionId
    self.vout = vout
  }
  
  enum Failure: Error {
    case expectedTransactionId
    case expectedVout
  }
  
  init(from json: JsonDictionary) throws {
    enum JsonAttribute: JsonAttributeName {
      case transactionId = "transaction_id"
      case vout
      
      var key: String { return rawValue }
    }
    
    guard let transactionId = json[JsonAttribute.transactionId.key] as? String else {
      print("JSON \(json)")
      
      throw Failure.expectedTransactionId
    }
    
    guard let vout = json[JsonAttribute.vout.key] as? NSNumber else { throw Failure.expectedVout }
    
    self.transactionId = transactionId
    self.vout = vout.intValue
  }
}
