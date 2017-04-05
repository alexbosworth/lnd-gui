//
//  PeersViewController.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 4/4/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Cocoa

struct Peer {
  let networkAddress: String // FIXME: - make struct
  let publicKey: String // FIXME: - make struct
  
  enum PeerJsonFailure: String, Error {
    case expectedNetworkAddress
    case expectedPublicKey
  }
  
  init(from json: [String: Any]) throws {
    guard let networkAddress = json["network_address"] as? String else { throw PeerJsonFailure.expectedNetworkAddress }
    guard let publicKey = json["public_key"] as? String else { throw PeerJsonFailure.expectedPublicKey }
    
    self.networkAddress = networkAddress
    self.publicKey = publicKey
  }
}

/** PeersViewController is a view controller for creating invoices
 */
class PeersViewController: NSViewController {
  @IBOutlet weak var peersTableView: NSTableView?
  
  enum GetPeersFailure: String, Error {
    case expectedPeerData
    case expectedPeerJson
  }
  
  lazy var peers: [Peer] = []
  
  func refreshPeers() {
    let url = URL(string: "http://localhost:10553/v0/peers/")!
    let session = URLSession.shared
    
    var request = URLRequest(url: url)

    request.httpMethod = "GET"
    
    let task = session.dataTask(with: request) { [weak self] data, urlResponse, error in
      guard let data = data else { return print(GetPeersFailure.expectedPeerData) }
      
      let dataDownloadedAsJson = try? JSONSerialization.jsonObject(with: data, options: .allowFragments)
      
      guard let peers = dataDownloadedAsJson as? [[String: Any]] else { return print(GetPeersFailure.expectedPeerJson) }
      
      do {
        let peers = try peers.map { try Peer(from: $0) }
        
        DispatchQueue.main.async {
          self?.peers = peers
          
          self?.peersTableView?.reloadData()
        }
      } catch {
        print(error)
      }
    }
    
    task.resume()
  }

}
