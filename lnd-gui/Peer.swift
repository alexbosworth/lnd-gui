//
//  Peer.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 4/15/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Foundation

struct Peer {
  let id: Int
  let networkAddress: String // FIXME: - make struct
  let ping: TimeInterval
  let transferedBytes: ByteTransfer
  let transferedValue: ValueTransfer
  
  struct ByteTransfer {
    let received: UInt
    let sent: UInt
  }

  struct ValueTransfer {
    let received: Tokens
    let sent: Tokens
  }
  
  enum ParseJsonFailure: String, Error {
    case expectedBytesReceived
    case expectedBytesSent
    case expectedId
    case expectedNetworkAddress
    case expectedPingTime
    case expectedPublicKey
    case expectedTokensReceived
    case expectedTokensSent
  }
  
  init(from json: [String: Any]) throws {
    enum JsonAttribute: String {
      case bytesReceived = "bytes_received"
      case bytesSent = "bytes_sent"
      case id
      case networkAddress = "network_address"
      case pingTime = "ping_time"
      case publicKey = "public_key"
      case tokensReceived = "tokens_received"
      case tokensSent = "tokens_sent"
      
      var key: String { return rawValue }
    }
    
    guard let bytesReceived = json[JsonAttribute.bytesReceived.key] as? NSNumber else {
      throw ParseJsonFailure.expectedBytesReceived
    }
    
    guard let bytesSent = json[JsonAttribute.bytesSent.key] as? NSNumber else {
      throw ParseJsonFailure.expectedBytesSent
    }
    
    guard let id = json[JsonAttribute.id.key] as? NSNumber else { throw ParseJsonFailure.expectedId }
    
    guard let networkAddress = json[JsonAttribute.networkAddress.key] as? String else {
      throw ParseJsonFailure.expectedNetworkAddress
    }
    
    guard let pingTime = json[JsonAttribute.pingTime.key] as? NSNumber else { throw ParseJsonFailure.expectedPingTime }
    
    guard let tokensReceived = json[JsonAttribute.tokensReceived.key] as? NSNumber else {
      throw ParseJsonFailure.expectedTokensReceived
    }
    
    guard let tokensSent = json[JsonAttribute.tokensSent.key] as? NSNumber else {
      throw ParseJsonFailure.expectedTokensSent
    }
    
    self.id = id.intValue
    self.networkAddress = networkAddress
    self.ping = pingTime.doubleValue
    self.transferedBytes = ByteTransfer(received: bytesReceived.uintValue, sent: bytesSent.uintValue)
    self.transferedValue = ValueTransfer(received: tokensReceived.uint64Value, sent: tokensSent.uint64Value)
  }
}
