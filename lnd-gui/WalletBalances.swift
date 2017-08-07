//
//  WalletBalances.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 8/6/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Foundation

/** Token balances
 */
struct WalletBalances: JsonInitialized {
  let chainTokens: Tokens
  let channelTokens: Tokens
  let pendingChainTokens: Tokens
  let pendingChannelTokens: Tokens
  
  enum JsonAttribute: JsonAttributeName {
    case chainBalance = "chain_balance"
    case channelBalance = "channel_balance"
    case pendingChainBalance = "pending_chain_balance"
    case pendingChannelBalance = "pending_channel_balance"
    
    var asKey: JsonAttributeName { return rawValue }
  }
  
  enum JsonParseFailure: Error {
    case missing(JsonAttribute)
  }
  
  init(from data: Data?) throws {
    let json = try type(of: self).jsonDictionaryFromData(data)
    
    guard let chainBalance = (json[JsonAttribute.chainBalance.asKey] as? NSNumber)?.tokensValue else {
      throw JsonParseFailure.missing(.chainBalance)
    }
    
    guard let channelBalance = (json[JsonAttribute.channelBalance.asKey] as? NSNumber)?.tokensValue else {
      throw JsonParseFailure.missing(.channelBalance)
    }
    
    guard let pendingChainBalance = (json[JsonAttribute.pendingChainBalance.asKey] as? NSNumber)?.tokensValue else {
      throw JsonParseFailure.missing(.pendingChainBalance)
    }
    
    guard let pendingChannelBalance = (json[JsonAttribute.pendingChannelBalance.asKey] as? NSNumber)?.tokensValue else {
      throw JsonParseFailure.missing(.pendingChannelBalance)
    }
    
    self.chainTokens = chainBalance
    self.channelTokens = channelBalance
    self.pendingChainTokens = pendingChainBalance
    self.pendingChannelTokens = pendingChannelBalance
  }
  
  var spendableBalance: Tokens { return chainTokens + channelTokens }
}
