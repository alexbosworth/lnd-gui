//
//  Connection.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 4/15/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Foundation

struct Connection {
  let channels: [Channel]
  let peers: [Peer]
  let publicKey: PublicKey
  
  var balance: Tokens { return channels.reduce(Tokens()) { return $0 + $1.balance.local } }
  
  var bestPing: TimeInterval? { return peers.min(by: { $0.ping < $1.ping })?.ping }

  enum ParseJsonFailure: String, Error {
    case expectedChannels
    case expectedPeers
    case expectedPublicKey
  }
  
  init(from json: [String: Any]) throws {
    enum JsonAttribute: String {
      case channels
      case peers
      case publicKey = "public_key"
      
      var key: String { return rawValue }
    }
    
    guard let channels = json[JsonAttribute.channels.key] as? [[String: Any]] else {
      throw ParseJsonFailure.expectedChannels
    }
    
    guard let peers = json[JsonAttribute.peers.key] as? [[String: Any]] else { throw ParseJsonFailure.expectedPeers }
    
    guard let publicKey = json[JsonAttribute.publicKey.key] as? String else { throw ParseJsonFailure.expectedPublicKey }

    self.channels = try channels.map { try Channel(from: $0) }
    self.peers = try peers.map { try Peer(from: $0) }
    self.publicKey = PublicKey(from: publicKey)
  }
}
