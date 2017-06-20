//
//  AddPeerViewController.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 4/19/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Cocoa

/** Add peer dialog view controller
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
    guard let ip = ipValue, let _ = try? IpAddress(from: ip) else { return }
    
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
    guard let ip = ip, let key = publicKeyHex else { return }
    
    try addPeer(ip: try IpAddress(from: ip), publicKey: try PublicKey(from: key))
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
