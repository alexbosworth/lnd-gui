//
//  DaemonsViewController.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 7/29/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Cocoa

/** Daemons view controller

 There are multiple network daemons involved in the Li
 */
class DaemonsViewController: NSViewController {
  // MARK: - @IBActions
  
  @IBAction func pressedManageConnectionsButton(_ button: NSButton) {
    showConnections()
  }

  // MARK: - @IBOutlets
  
  @IBOutlet weak var blockchainPeersTextField: NSTextField?
  
  @IBOutlet weak var connectionsCountTextField: NSTextField?
  
  @IBOutlet weak var connectivityStatusImageView: NSImageView?

  @IBOutlet weak var connectivityStatusTextField: NSTextField?
  
  // MARK: - Properties

  var connectionsCount: Int? { didSet { updateConnectionsCount() } }
  
  var connectivityStatus: ConnectivityStatus = .initializing { didSet { updatedConnectivity() } }
  
  lazy var showConnections: (() -> ()) = {}
  
  func updateConnectionsCount() {
    let connectionsCount = (self.connectionsCount ?? Int()) as Int
    
    let plural = connectionsCount == 1 ? "" : "s"
    
    connectionsCountTextField?.stringValue = "\(connectionsCount) active connection\(plural)."
  }
  
  func updatedConnectivity() {
    connectivityStatusImageView?.image = connectivityStatus.statusImage
    connectivityStatusTextField?.stringValue = connectivityStatus.localizedDescription

    let blockchainStatus: String
    let blockchainStatusComment = "Bitcoin network connectivity status"
    
    switch connectivityStatus {
    case .connected:
      blockchainStatus = "Connected to the Bitcoin Network"
      
    case .disconnected:
      blockchainStatus = "Disconnected"
      connectivityStatusTextField?.stringValue = connectivityStatus.localizedDescription
      
    case .initializing:
      blockchainStatus = "Connecting..."
      connectivityStatusTextField?.stringValue = connectivityStatus.localizedDescription
    }
    
    blockchainPeersTextField?.stringValue = NSLocalizedString(blockchainStatus, comment: blockchainStatusComment)
  }
}

extension DaemonsViewController {
  override func viewDidLoad() {
    super.viewDidLoad()
    
    updatedConnectivity()
  }
}
