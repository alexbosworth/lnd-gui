//
//  Transaction.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 4/15/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Foundation

// FIXME: - include fee, hops and payment req
// FIXME: - reorganize
struct Transaction {
  let confirmed: Bool
  let createdAt: Date?
  let destination: DestinationType
  let id: String
  let outgoing: Bool
  let tokens: Tokens
  
  enum DestinationType {
    case chain
    case received(memo: String)
    case sent(publicKey: String, paymentId: String)
  }
  
  enum JsonParseError: String, Error {
    case expectedAmount
    case expectedConfirmedFlag
    case expectedDestination
    case expectedId
    case expectedOutgoingFlag
    case expectedType
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
  
  init(from json: [String: Any]) throws {
    guard let confirmed = (json["confirmed"] as? Bool) else { throw JsonParseError.expectedConfirmedFlag }
    
    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
    
    let createdAtString = json["created_at"] as? String
    let createdAt: Date?
      
    if let str = createdAtString { createdAt = dateFormatter.date(from: str) } else { createdAt = nil }

    guard let id = json["id"] as? String else { throw JsonParseError.expectedId }
    
    guard let outgoing = (json["outgoing"] as? Bool) else { throw JsonParseError.expectedOutgoingFlag }
    
    guard let tokens = (json["tokens"] as? NSNumber)?.tokensValue else { throw JsonParseError.expectedAmount }
    
    let memo = json["memo"] as? String
    let destinationId = json["destination"] as? String

    guard let networkType = NetworkType(from: json["type"] as? String) else { throw JsonParseError.expectedType }
    
    switch (networkType, outgoing) {
    case (.chain, _):
      destination = DestinationType.chain
      
    case (.channel, false):
      destination = DestinationType.received(memo: (memo ?? String()) as String)
      
    case (.channel, true):
      guard let publicKey = destinationId else { throw JsonParseError.expectedDestination }
      
      destination = DestinationType.sent(publicKey: publicKey, paymentId: id)
    }
  
    self.confirmed = confirmed
    self.createdAt = createdAt
    self.id = id
    self.outgoing = outgoing
    self.tokens = tokens
  }
}
