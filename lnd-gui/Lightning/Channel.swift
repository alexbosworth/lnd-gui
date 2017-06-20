//
//  Channel.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 4/15/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Foundation

struct Channel {
  /** Active state
   */
  enum State { case active, closing, inactive, opening }

  /** Peer balance
   */
  struct Balance {
    let local: Tokens
    let remote: Tokens
  }
  
  /** Current channel token balance
   */
  let balance: Balance

  /** Channel id number
   */
  let id: String?

  /** Channel chain transaction output
   */
  let outpoint: Outpoint

  /** Total received tokens
   */
  let received: Tokens
  
  /** Total sent tokens
   */
  let sent: Tokens
  
  /** Current channel state
   */
  let state: State
  
  /** Total channel transfers
   */
  let transfersCount: UInt
  
  /** Total balance
   */
  let unsettledBalance: Tokens?
  
  /** Channel data JSON parse failures
   */
  enum ParseJsonFailure: Error {
    case missingAttribute(JsonAttribute)
  }

  /** Channel data JSON keys
   */
  enum JsonAttribute: String {
    case id
    case isActive = "is_active"
    case isClosing = "is_closing"
    case isOpening = "is_opening"
    case localBalance = "local_balance"
    case received
    case remoteBalance = "remote_balance"
    case sent
    case transactionId = "transaction_id"
    case transactionVout = "transaction_vout"
    case transfersCount = "transfers_count"
    case unsettledBalance = "unsettled_balance"
    
    /** Attribute String value
     */
    var key: String { return rawValue }
  }

  /** Create channel from JSON
   */
  init(from json: [String: Any]) throws {
    
    let id = json[JsonAttribute.id.key] as? String
    
    guard let isActive = json[JsonAttribute.isActive.key] as? Bool else {
      throw ParseJsonFailure.missingAttribute(.isActive)
    }

    guard let isClosing = json[JsonAttribute.isClosing.key] as? Bool else {
      throw ParseJsonFailure.missingAttribute(.isClosing)
    }

    guard let isOpening = json[JsonAttribute.isOpening.key] as? Bool else {
      throw ParseJsonFailure.missingAttribute(.isOpening)
    }
    
    guard let localBalance = json[JsonAttribute.localBalance.key] as? NSNumber else {
      throw ParseJsonFailure.missingAttribute(.localBalance)
    }
    
    guard let received = json[JsonAttribute.received.key] as? NSNumber else {
      throw ParseJsonFailure.missingAttribute(.received)
    }
    
    guard let remoteBalance = json[JsonAttribute.remoteBalance.key] as? NSNumber else {
      throw ParseJsonFailure.missingAttribute(.remoteBalance)
    }
    
    guard let sent = json[JsonAttribute.sent.key] as? NSNumber else {
      throw ParseJsonFailure.missingAttribute(.sent)
    }
    
    guard let transactionId = json[JsonAttribute.transactionId.key] as? String else {
      throw ParseJsonFailure.missingAttribute(.transactionId)
    }
    
    guard let transactionVout = json[JsonAttribute.transactionVout.key] as? NSNumber else {
      throw ParseJsonFailure.missingAttribute(.transactionVout)
    }
    
    guard let transfersCount = json[JsonAttribute.transfersCount.key] as? NSNumber else {
      throw ParseJsonFailure.missingAttribute(.transfersCount)
    }
    
    let unsettledBalance = json[JsonAttribute.unsettledBalance.key] as? NSNumber
    
    self.balance = Balance(local: localBalance.tokensValue, remote: remoteBalance.tokensValue)
    self.id = id
    self.outpoint = Outpoint(transactionId: try TransactionHash(from: transactionId), vout: transactionVout.uint32Value)
    self.received = received.tokensValue
    self.sent = sent.tokensValue

    switch (isOpening, isClosing, isActive) {
    case (true, _, _):
      state = .opening
      
    case (false, true, _):
      state = .closing
      
    case (false, false, true):
      state = .active
      
    case (false, false, false):
      state = .inactive
    }
    
    self.transfersCount = transfersCount.uintValue
    self.unsettledBalance = unsettledBalance?.tokensValue
  }
}
