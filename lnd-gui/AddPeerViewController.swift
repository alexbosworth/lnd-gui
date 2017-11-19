//
//  AddPeerViewController.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 4/19/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Cocoa

/** Add peer dialog view controller
 
 FIXME: - make the peer address be pubkey@ip format
 FIXME: - when chain is still syncing, show indicator that peer cannot be added
 FIXME: - show pending state of peer
 */
class AddPeerViewController: NSViewController {
  // MARK: - @IBActions
  
  /** Pressed add peer button
   */
  @IBAction func pressedAddPeerButton(_ sender: NSButton) {
    do { try addPeer(ip: ipValue, publicKeyHex: publicKeyValue) } catch { reportError(error) }
  }
  
  // MARK: - @IBOutlets
  
  /** Add peer button
   */
  @IBOutlet weak var addPeerButton: NSButton?
  
  /** Host test field
   */
  @IBOutlet weak var hostTextField: NSTextField?
  
  /** Public key field
   */
  @IBOutlet weak var publicKeyTextField: NSTextField?
  
  // MARK: - Properties
  
  var addedPeer: (() -> ())?
  
  /** Report error
   */
  lazy var reportError: (Error) -> () = { _ in }
}

// MARK: - ErrorReporting
extension AddPeerViewController: ErrorReporting {}

// MARK: - NSTextViewDelegate
extension AddPeerViewController: NSTextViewDelegate {
  /** Control text changed
   */
  override func controlTextDidChange(_ obj: Notification) {
    addPeerButton?.isEnabled = false

    // Confirm that the host looks valid
    guard let ip = ipValue, !ip.isEmpty else { return }
    
    // Confirm that the node key looks valid
    guard let publicKeyValue = publicKeyValue, let _ = try? PublicKey(from: publicKeyValue) else { return }
    
    addPeerButton?.isEnabled = true
  }
  
  /** Input ip value
   */
  fileprivate var ipValue: String? { return hostTextField?.stringValue }

  /** Public key value
   */
  fileprivate var publicKeyValue: String? { return publicKeyTextField?.stringValue }
}

// MARK: - Navigation
extension AddPeerViewController {
  /** Add a peer
   */
  fileprivate func addPeer(ip: String?, publicKeyHex: String?) throws {
    guard let ip = ip, !ip.isEmpty, let key = publicKeyHex, !key.isEmpty else { return }
    
    try addPeer(ip: ip, publicKey: try PublicKey(from: key))
  }

  /** Add a peer
   */
  private func addPeer(ip: String, publicKey: PublicKey) throws {
    addPeerButton?.isEnabled = false
    
    try Daemon.addPeer(ip: ip, publicKey: publicKey) { [weak self] result in
      self?.addPeerButton?.isEnabled = true

      switch result {
      case .error(let error):
        self?.reportError(error)
        
      case .success:
        self?.addedPeer?()
        
        self?.dismiss(self)
      }
    }
  }
}
