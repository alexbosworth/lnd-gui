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
class AddPeerViewController: NSViewController {
  // MARK: - @IBActions
  
  /** Pressed add peer button
   */
  @IBAction func pressedAddPeerButton(_ sender: NSButton) {
    do {
      guard let serializedIp = hostTextField?.stringValue, let publicKeyHex = publicKeyTextField?.stringValue else {
        return
      }

      addPeer(ip: try IpAddress(from: serializedIp), publicKey: try PublicKey(from: publicKeyHex))
    } catch {
      print("ERROR", error)
    }
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

extension AddPeerViewController {
  func addPeer(ip: IpAddress, publicKey: PublicKey) {
    addPeerButton?.isEnabled = false
    
    do {
      try Daemon.addPeer(ip: ip, publicKey: publicKey) { [weak self] result in
        DispatchQueue.main.async {
          switch result {
          case .error(let error):
            self?.addPeerButton?.isEnabled = true

            print("ERROR", error)
            
          case .success:
            self?.dismiss(self)
          }
        }
      }
    } catch {
      print("ERROR", error)
    }
  }
}
