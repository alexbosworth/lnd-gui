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
  enum ParseJsonFailure: String, Error {
    case expectedIsActive
    case expectedIsClosing
    case expectedIsOpening
    case expectedLocalBalance
    case expectedReceived
    case expectedRemoteBalance
    case expectedSentValue
    case expectedTransactionId
    case expectedTransactionVout
    case expectedTransfersCount
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
    
    guard let isActive = json[JsonAttribute.isActive.key] as? Bool else { throw ParseJsonFailure.expectedIsActive }

    guard let isClosing = json[JsonAttribute.isClosing.key] as? Bool else { throw ParseJsonFailure.expectedIsClosing }

    guard let isOpening = json[JsonAttribute.isOpening.key] as? Bool else { throw ParseJsonFailure.expectedIsOpening }
    
    guard let localBalance = json[JsonAttribute.localBalance.key] as? NSNumber else {
      throw ParseJsonFailure.expectedLocalBalance
    }
    
    guard let received = json[JsonAttribute.received.key] as? NSNumber else { throw ParseJsonFailure.expectedReceived }
    
    guard let remoteBalance = json[JsonAttribute.remoteBalance.key] as? NSNumber else {
      throw ParseJsonFailure.expectedRemoteBalance
    }
    
    guard let sent = json[JsonAttribute.sent.key] as? NSNumber else { throw ParseJsonFailure.expectedSentValue }
    
    guard let transactionId = json[JsonAttribute.transactionId.key] as? String else {
      throw ParseJsonFailure.expectedTransactionId
    }
    
    guard let transactionVout = json[JsonAttribute.transactionVout.key] as? NSNumber else {
      throw ParseJsonFailure.expectedTransactionVout
    }
    
    guard let transfersCount = json[JsonAttribute.transfersCount.key] as? NSNumber else {
      throw ParseJsonFailure.expectedTransfersCount
    }
    
    let unsettledBalance = json[JsonAttribute.unsettledBalance.key] as? NSNumber
    
    self.balance = Balance(local: localBalance.tokensValue, remote: remoteBalance.tokensValue)
    self.id = id
    self.outpoint = Outpoint(transactionId: try TransactionHash(from: transactionId), vout: transactionVout.uint32Value)
    self.received = received.tokensValue
    self.sent = sent.tokensValue

    if isOpening {
      self.state = .opening
    } else if isClosing {
      self.state = .closing
    } else if isActive {
      self.state = .active
    } else {
      self.state = .inactive
    }
    
    self.transfersCount = transfersCount.uintValue
    self.unsettledBalance = unsettledBalance?.tokensValue
  }
}
