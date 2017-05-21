//
//  AddPeerViewController.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 4/19/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Cocoa

/** Add peer dialog
 */
class AddPeerViewController: NSViewController, ErrorReporting {
  // MARK: - @IBActions
  
  /** Pressed add peer button
   */
  @IBAction func pressedAddPeerButton(_ sender: NSButton) {
    addPeer(ip: hostTextField?.stringValue, publicKeyHex: publicKeyTextField?.stringValue)
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
  
  /** Report error
   */
  lazy var reportError: (Error) -> () = { _ in }
}

// MARK: - NSTextViewDelegate
extension AddPeerViewController: NSTextViewDelegate {
  /** Control text changed
   */
  override func controlTextDidChange(_ obj: Notification) {
    addPeerButton?.isEnabled = false

    // Confirm that the public key and host look valid
    guard
      let host = hostTextField?.stringValue,
      let _ = try? IpAddress(from: host),
      let publicKey = publicKeyTextField?.stringValue,
      let _ = try? PublicKey(from: publicKey)
      else
    {
      return
    }
    
    addPeerButton?.isEnabled = true
  }
}

// MARK: - Navigation
extension AddPeerViewController {
  /** Add a peer
   */
  fileprivate func addPeer(ip: String?, publicKeyHex: String?) {
    guard let ip = ip, let key = publicKeyHex else { return }
    
    do { try addPeer(ip: try IpAddress(from: ip), publicKey: try PublicKey(from: key)) } catch { reportError(error) }
  }

  /** Add a peer
   */
  private func addPeer(ip: IpAddress, publicKey: PublicKey) throws {
    addPeerButton?.isEnabled = false
    
    try Daemon.addPeer(ip: ip, publicKey: publicKey) { [weak self] result in
      self?.addPeerButton?.isEnabled = true

      switch result {
      case .error(let error):
        self?.reportError(error)
        
      case .success:
        self?.dismiss(self)
      }
    }
  }
}
