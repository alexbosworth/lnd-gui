//
//  Transaction.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 4/15/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Foundation

/** Transactions are transfers of tokens through the Lightning Network or via Blockchain settlement.
 // FIXME: - include fee, hops and payment req
 // FIXME: - reorganize into an enum, with shared values and distinct types
 */
struct Transaction {
  let confirmed: Bool
  let createdAt: Date?
  let destination: DestinationType
  let id: String
  let outgoing: Bool
  let tokens: Tokens
  
  enum DestinationType {
    case chain
    case received(Invoice)
    case sent(publicKey: String, paymentId: String)
  }
  
  enum JsonParseError: Error {
    case missing(JsonAttribute)
  }
  
  enum NetworkType {
    case chain
    case channel
    
    init?(from transactionType: String?) {
      guard let transactionType = transactionType else { return nil }
      
      switch transactionType {
      case "chain_transaction":
        self = .chain
        
      case "channel_transaction":
        self = .channel
        
      default:
        return nil
      }
    }
  }

  enum JsonAttribute: JsonAttributeName {
    case confirmed
    case createdAt = "created_at"
    case destination
    case id
    case outgoing
    case tokens
    case type
    
    var asKey: String { return rawValue }
  }
  
  init(from json: [String: Any]) throws {
    guard let confirmed = (json[JsonAttribute.confirmed.asKey] as? Bool) else {
      throw JsonParseError.missing(.confirmed)
    }
    
    let createdAtString = json[JsonAttribute.createdAt.asKey] as? String
    let createdAt: Date?
      
    if let str = createdAtString { createdAt = DateFormatter().date(fromIso8601: str) } else { createdAt = nil }

    guard let id = json[JsonAttribute.id.asKey] as? String else { throw JsonParseError.missing(.id) }
    
    guard let outgoing = (json[JsonAttribute.outgoing.asKey] as? Bool) else { throw JsonParseError.missing(.outgoing) }
    
    guard let tokens = (json[JsonAttribute.tokens.asKey] as? NSNumber)?.tokensValue else {
      throw JsonParseError.missing(.tokens)
    }
    
    let destinationId = json[JsonAttribute.destination.asKey] as? String

    guard let networkType = NetworkType(from: json[JsonAttribute.type.asKey] as? String) else {
      throw JsonParseError.missing(.type)
    }
    
    switch (networkType, outgoing) {
    case (.chain, _):
      destination = DestinationType.chain
      
    case (.channel, false):
      destination = DestinationType.received(try Invoice(from: json))
      
    case (.channel, true):
      guard let publicKey = destinationId else { throw JsonParseError.missing(.destination) }
      
      destination = DestinationType.sent(publicKey: publicKey, paymentId: id)
    }
  
    self.confirmed = confirmed
    self.createdAt = createdAt
    self.id = id
    self.outgoing = outgoing
    self.tokens = tokens
  }
}

extension Transaction: Equatable {}

func ==(lhs: Transaction, rhs: Transaction) -> Bool {
  return lhs.id == rhs.id
}

extension Transaction: Hashable {
  var hashValue: Int { return id.hashValue }
}

