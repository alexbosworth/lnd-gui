//
//  Connection.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 4/15/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Foundation

typealias JsonAttributeName = String

/** Connection
 */
struct Connection {
  let channels: [Channel]
  let peers: [Peer]
  let publicKey: PublicKey
  
  var balance: Tokens { return channels.reduce(Tokens()) { return $0 + $1.balance.local } }
  
  var bestPing: TimeInterval? { return peers.min(by: { $0.ping < $1.ping })?.ping }

  enum JsonAttribute: JsonAttributeName {
    case channels
    case peers
    case publicKey = "public_key"
    
    var key: String { return rawValue }
  }

  enum ParseJsonFailure: Error {
    case missing(JsonAttribute)
  }
  
  init(from json: [String: Any]) throws {
    guard let channels = json[JsonAttribute.channels.key] as? [[String: Any]] else {
      throw ParseJsonFailure.missing(.channels)
    }

    guard let peers = json[JsonAttribute.peers.key] as? [[String: Any]] else {
      throw ParseJsonFailure.missing(.peers)
    }
    
    guard let publicKey = json[JsonAttribute.publicKey.key] as? String else {
      throw ParseJsonFailure.missing(.publicKey)
    }

    self.channels = try channels.map { try Channel(from: $0) }
    self.peers = try peers.map { try Peer(from: $0) }
    self.publicKey = try PublicKey(from: publicKey)
  }
}
