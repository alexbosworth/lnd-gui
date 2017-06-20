//
//  Peer.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 4/15/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Foundation

/** Peer
 */
struct Peer {
  let id: Int
  let networkAddress: IpAddress
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
  
  enum ParseJsonFailure: Error {
    case missing(JsonAttribute)
  }

  enum JsonAttribute: JsonAttributeName {
    case bytesReceived = "bytes_received"
    case bytesSent = "bytes_sent"
    case id
    case networkAddress = "network_address"
    case pingTime = "ping_time"
    case publicKey = "public_key"
    case tokensReceived = "tokens_received"
    case tokensSent = "tokens_sent"
    
    var asKey: JsonAttributeName { return rawValue }
  }
  
  init(from json: [String: Any]) throws {
    guard let bytesReceived = json[JsonAttribute.bytesReceived.asKey] as? NSNumber else {
      throw ParseJsonFailure.missing(.bytesReceived)
    }
    
    guard let bytesSent = json[JsonAttribute.bytesSent.asKey] as? NSNumber else {
      throw ParseJsonFailure.missing(.bytesSent)
    }
    
    guard let id = json[JsonAttribute.id.asKey] as? NSNumber else { throw ParseJsonFailure.missing(.id) }
    
    guard let networkAddress = json[JsonAttribute.networkAddress.asKey] as? String else {
      throw ParseJsonFailure.missing(.networkAddress)
    }
    
    guard let pingTime = json[JsonAttribute.pingTime.asKey] as? NSNumber else {
      throw ParseJsonFailure.missing(.pingTime)
    }
    
    guard let tokensReceived = json[JsonAttribute.tokensReceived.asKey] as? NSNumber else {
      throw ParseJsonFailure.missing(.tokensReceived)
    }
    
    guard let tokensSent = json[JsonAttribute.tokensSent.asKey] as? NSNumber else {
      throw ParseJsonFailure.missing(.tokensSent)
    }
    
    self.id = id.intValue
    self.networkAddress = try IpAddress(from: networkAddress)
    self.ping = pingTime.doubleValue
    self.transferedBytes = ByteTransfer(received: bytesReceived.uintValue, sent: bytesSent.uintValue)
    self.transferedValue = ValueTransfer(received: tokensReceived.uint64Value, sent: tokensSent.uint64Value)
  }
}
