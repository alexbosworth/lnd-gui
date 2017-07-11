//
//  BlockchainTransaction.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 7/8/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Foundation

/** Blockchain transaction
 */
struct BlockchainTransaction: TokenTransaction {
  let confirmationCount: Int
  let createdAt: Date?
  let id: String
  let inputs: [BlockchainTransactionInput]?
  let isOutgoing: Bool?
  let outputs: [BlockchainTransactionOutput]?
  let sendTokens: Tokens?
  
  var isConfirmed: Bool? { return confirmationCount > Int() }
  
  init(
    confirmationCount: Int,
    id: String,
    inputs: [BlockchainTransactionInput],
    outputs: [BlockchainTransactionOutput])
  {
    self.confirmationCount = confirmationCount
    self.createdAt = nil
    self.id = id
    self.inputs = inputs
    self.isOutgoing = nil
    self.outputs = outputs
    self.sendTokens = nil
  }
  
  enum Failure: Error {
    case expectedConfirmationCount
    case expectedInputs
    case expectedOutputs
    case expectedTransactionId
  }

  enum JsonAttribute: JsonAttributeName {
    case confirmationCount = "confirmation_count"
    case createdAt = "created_at"
    case id
    case inputs
    case isOutgoing = "outgoing"
    case outputs
    case tokens
    
    var asKey: JsonAttributeName { return rawValue }
  }
  
  init(from json: JsonDictionary) throws {
    if let amount = json[JsonAttribute.tokens.asKey] as? NSNumber {
      sendTokens = amount.tokensValue
    } else {
      sendTokens = nil
    }
    
    guard let confirmationCount = json[JsonAttribute.confirmationCount.asKey] as? NSNumber else {
      throw Failure.expectedConfirmationCount
    }
    
    guard let id = json[JsonAttribute.id.asKey] as? String else { throw Failure.expectedTransactionId }
    
    self.confirmationCount = confirmationCount.intValue

    let createdAtString = json[JsonAttribute.createdAt.asKey] as? String
    
    if let str = createdAtString { createdAt = DateFormatter().date(fromIso8601: str) } else { createdAt = nil }
    
    self.id = id
    
    if let inputs = json[JsonAttribute.inputs.asKey] as? [JsonDictionary] {
      self.inputs = try inputs.map { try BlockchainTransactionInput(from: $0) }
    } else {
      self.inputs = nil
    }
    
    if let isOutgoing = json[JsonAttribute.isOutgoing.asKey] as? Bool {
      self.isOutgoing = isOutgoing
    } else {
      self.isOutgoing = nil
    }
    
    if let outputs = json[JsonAttribute.outputs.asKey] as? [JsonDictionary] {
      self.outputs = try outputs.map { try BlockchainTransactionOutput(from: $0) }
    } else {
      self.outputs = nil
    }
  }
}
