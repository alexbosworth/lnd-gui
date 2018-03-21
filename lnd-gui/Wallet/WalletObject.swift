//
//  WalletObject.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 8/6/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Foundation

/** Wallet objects
 */
enum WalletObject: JsonInitialized {
  case invoice(LightningInvoice)
  case transaction(Transaction)
  
  enum JsonAttribute: JsonAttributeName {
    case type
    
    var asKey: JsonAttributeName { return rawValue }
  }
  
  enum JsonParseFailure: Error {
    case unrecognizedType(String?)
  }
  
  enum RowType: String {
    case chainTransaction = "chain_transaction"
    case channelTransaction = "channel_transaction"
    case invoice
    
    init?(from string: String?) {
      guard let string = string, let rowType = type(of: self).init(rawValue: string) else { return nil }
      
      self = rowType
    }
  }
  
  init(from json: Data?) throws {
    let json = try type(of: self).jsonDictionaryFromData(json)
    
    let type = json[JsonAttribute.type.asKey] as? String
    
    guard let rowType = RowType(from: type) else { throw JsonParseFailure.unrecognizedType(type) }
    
    switch rowType {
    case .chainTransaction, .channelTransaction:
      self = .transaction(try Transaction(from: json))
      
    case .invoice:
      self = .invoice(try LightningInvoice(from: json))
    }
  }
}
