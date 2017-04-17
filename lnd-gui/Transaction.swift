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
  let destination: DestinationType
  let createdAt: Date
  let outgoing: Bool
  let tokens: Tokens
  
  enum DestinationType {
    case received(memo: String)
    case sent(publicKey: String, paymentId: String)
  }
  
  enum JsonParseError: String, Error {
    case expectedAmount
    case expectedConfirmedFlag
    case expectedCreatedAtDate
    case expectedMemo
    case expectedOutgoingFlag
    case expectedSentDestination
  }
  
  init(from json: [String: Any]) throws {
    guard let confirmed = (json["confirmed"] as? Bool) else { throw JsonParseError.expectedConfirmedFlag }
    
    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
    
    guard
      let createdAtString = (json["created_at"] as? String),
      let createdAt = dateFormatter.date(from: createdAtString) else { throw JsonParseError.expectedCreatedAtDate }
    
    guard let outgoing = (json["outgoing"] as? Bool) else { throw JsonParseError.expectedOutgoingFlag }
    
    guard let tokens = (json["tokens"] as? NSNumber)?.tokensValue else { throw JsonParseError.expectedAmount }
    
    self.confirmed = confirmed
    self.createdAt = createdAt
    self.outgoing = outgoing
    self.tokens = tokens
    
    switch outgoing {
    case false:
      guard let memo = json["memo"] as? String else { throw JsonParseError.expectedMemo }
      
      destination = DestinationType.received(memo: memo)
      
    case true:
      guard let publicKey = json["destination"] as? String, let paymentId = json["id"] as? String else {
        throw JsonParseError.expectedSentDestination
      }
      
      destination = DestinationType.sent(publicKey: publicKey, paymentId: paymentId)
    }
  }
}
