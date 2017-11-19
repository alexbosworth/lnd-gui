//
//  Transaction.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 4/15/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Foundation

protocol TokenTransaction {
  var createdAt: Date? { get }
  var id: String { get }
  var isConfirmed: Bool? { get }
}

enum LightningTransaction: TokenTransaction {
  case invoice(LightningInvoice)
  case payment(LightningPayment)

  init(from json: JsonDictionary) throws {
    guard let outgoing = json[JsonAttribute.outgoing.asKey] as? Bool else { throw JsonParseFailure.missing(.outgoing) }

    switch outgoing {
    case false:
      self = .invoice(try LightningInvoice(from: json))
      
    case true:
      self = .payment(try LightningPayment(from: json))
    }
  }
  
  enum JsonAttribute: JsonAttributeName {
    case outgoing
    
    var asKey: JsonAttributeName { return rawValue }
  }
  
  enum JsonParseFailure: Error {
    case missing(JsonAttribute)
  }
  
  var createdAt: Date? {
    switch self {
    case .invoice(let invoice):
      return invoice.createdAt
      
    case .payment(let payment):
      return payment.createdAt
    }
  }
  
  var id: String {
    switch self {
    case .invoice(let invoice):
      return invoice.id
      
    case .payment(let payment):
      return payment.id.hexEncoded
    }
  }
  
  var isConfirmed: Bool? {
    switch self {
    case .invoice(let invoice):
      return invoice.isConfirmed
      
    case .payment(let payment):
      return payment.isConfirmed
    }
  }

  var isOutgoing: Bool {
    switch self {
    case .invoice(_):
      return false
      
    case .payment(_):
      return true
    }
  }
  
  var memo: String? {
    switch self {
    case .invoice(let invoice):
      return invoice.memo
      
    case .payment(_):
      return nil
    }
  }
  
  var tokens: Tokens {
    switch self {
    case .invoice(let invoice):
      return invoice.tokens
      
    case .payment(let payment):
      return payment.tokens
    }
  }
}

enum Transaction {
  case blockchain(BlockchainTransaction)
  case lightning(LightningTransaction)

  enum TransactionType: String {
    case chain = "chain_transaction"
    case lightning = "channel_transaction"

    init?(from type: String) {
      if let t = type(of: self).init(rawValue: type) { self = t } else { return nil }
    }
  }
  
  init(from json: [String: Any]) throws {
    guard let t = json[JsonAttribute.type.asKey] as? String, let type = TransactionType(from: t) else {
      throw JsonParseError.missing(.type)
    }

    switch type {
    case .chain:
      self = .blockchain(try BlockchainTransaction(from: json))
      
    case .lightning:
      self = .lightning(try LightningTransaction(from: json))
    }
  }
  
  var asTokenTransaction: TokenTransaction {
    switch self {
    case .blockchain(let blockchainTransaction):
      return blockchainTransaction as TokenTransaction
      
    case .lightning(let lightningTransaction):
      return lightningTransaction as TokenTransaction
    }
  }
  
  var createdAt: Date? {
    switch self {
    case .blockchain(let blockchainTransaction):
      return blockchainTransaction.createdAt
      
    case .lightning(let lightningTransaction):
      switch lightningTransaction {
      case .invoice(let invoice):
        return invoice.createdAt
        
      case .payment(let payment):
        return payment.createdAt
      }
    }
  }
  
  var id: String {
    switch self {
    case .blockchain(let blockchainTransaction):
      return blockchainTransaction.id
      
    case .lightning(let lightningTransaction):
      return lightningTransaction.id
    }
  }
  
  var isConfirmed: Bool? {
    switch self {
    case .blockchain(let transaction):
      return transaction.isConfirmed
      
    case .lightning(let transaction):
      return transaction.isConfirmed
    }
  }
  
  var isOutgoing: Bool? {
    switch self {
    case .blockchain(let blockchainTransaction):
      return blockchainTransaction.isOutgoing
      
    case .lightning(let lightningTransaction):
      switch lightningTransaction {
      case .invoice(_):
        return false
        
      case .payment(_):
        return true
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

  enum JsonParseError: Error {
    case missing(JsonAttribute)
  }
  
  var sendTokens: Tokens? {
    switch self {
    case .blockchain(let blockchainTransaction):
      return blockchainTransaction.sendTokens
      
    case .lightning(let lightningTransaction):
      switch lightningTransaction {
      case .invoice(let invoice):
        return invoice.tokens
        
      case .payment(let payment):
        return payment.tokens
      }
    }
  }
}

extension Transaction: Equatable {}

func ==(lhs: Transaction, rhs: Transaction) -> Bool {
  return lhs.id == rhs.id
}

extension Transaction: Hashable {
  var hashValue: Int { return id.hashValue }
}

