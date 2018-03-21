//
//  Connection.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 4/15/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Foundation

typealias JsonAttributeName = String

/** Connection to another Lightning user
 */
struct Connection {
  /** Channels associated
   */
  let channels: [Channel]
  
  /** Peers associated
   */
  let peers: [Peer]
  
  /** User public key
   */
  let publicKey: PublicKey
  
  /** Channel local balance
   */
  var balance: Tokens { return channels.reduce(Tokens()) { return $0 + $1.balance.local } }
  
  /** Best ping time to connection
   */
  var bestPing: TimeInterval? { return peers.min(by: { $0.ping < $1.ping })?.ping }

  /** JSON serialized attributes
   */
  enum JsonAttribute: JsonAttributeName {
    case channels
    case peers
    case publicKey = "public_key"
    
    var key: String { return rawValue }
  }

  /** JSON parse errors
   */
  enum ParseJsonFailure: Error {
    case missing(JsonAttribute)

    var localizedDescription: String {
      switch self {
      case .missing(let attr):
        return "Expected Attribute Not Found: \(attr.key)"
      }
    }
  }
  
  /** Create from JSON representation
   */
  init(from json: JsonDictionary) throws {
    guard let channels = json[JsonAttribute.channels.key] as? [JsonDictionary] else {
      throw ParseJsonFailure.missing(.channels)
    }

    guard let peers = json[JsonAttribute.peers.key] as? [JsonDictionary] else {
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
