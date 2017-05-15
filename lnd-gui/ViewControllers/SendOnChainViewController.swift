//
//  SendOnChainViewController.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 5/7/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Cocoa

/** Send on chain view controller
 
  FIXME: - make this work
  FIXME: - show both fiat and chain balances
  FIXME: - do not allow non-numeric amounts
 */
class SendOnChainViewController: NSViewController {
  // MARK: - @IBActions
  
  /** Pressed amount options button
   */
  @IBAction func pressedAmountOptionsButton(_ sender: NSButton) {
    guard let event = NSApplication.shared().currentEvent else { return print("ERROR", "expected event") }

    let menu = NSMenu(title: "Currency")
    
    menu.addItem(withTitle: "tBTC", action: #selector(setCurrency(_:)), keyEquivalent: "")
    menu.addItem(withTitle: "tUSD", action: #selector(setCurrency(_:)), keyEquivalent: "")
      
    menu.items.forEach { $0.target = self }
      
    NSMenu.popUpContextMenu(menu, with: event, for: sender)
  }
  
  // MARK: - @IBOutlets
  
  /** Embedded commit view
   */
  @IBOutlet weak var commitSendView: NSView?

  /** Number of tokens to send
   */
  @IBOutlet weak var tokensToSendTextField: NSTextField?
  
  // MARK: - Properties

  /** Clear send
   */
  lazy var clear: () -> () = {}
  
  /** Confirm send view
   */
  fileprivate weak var commitSendViewController: CommitSendViewController?

  /** Payment to send
   */
  var paymentToSend: (String, Tokens)? {
    didSet {
      guard let paymentToSend = paymentToSend else {
        commitSendViewController?.paymentToSend = nil
        tokensToSendTextField?.stringValue = String()
        return
      }
      
      commitSendViewController?.paymentToSend = .chainSend(paymentToSend.0, paymentToSend.1)
    }
  }

  /** Commit send
   */
  lazy var send: (Payment) -> () = { _ in }
}

// MARK: - Navigation
extension SendOnChainViewController {
  /** Storyboard segue
   */
  enum Segue: StoryboardIdentifier {
    case previewSend = "PreviewChainSendSegue"
    
    init?(from segue: NSStoryboardSegue) {
      if let id = segue.identifier, let segue = type(of: self).init(rawValue: id) { self = segue } else { return nil }
    }
  }
  
  /** Prepare for segue
   */
  override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
    guard let commitSendViewController = segue.destinationController as? CommitSendViewController else {
      return print("ERROR", "expected commitSendViewController")
    }
    
    guard let _ = Segue(from: segue) else { return print("ERROR", "expected known segue") }
    
    self.commitSendViewController = commitSendViewController
    
    commitSendViewController.clearDestination = { [weak self] in self?.clear() }
    
    commitSendViewController.commitSend = { [weak self] payment in self?.send(payment) }
  }
}

extension SendOnChainViewController: NSTextFieldDelegate {
  /** Control text did change
   */
  override func controlTextDidChange(_ obj: Notification) {
    paymentToSend?.1 = Tokens()
    
    guard let amountString = tokensToSendTextField?.stringValue else { return }
    
    let number = (NSDecimalNumber(string: amountString) as Decimal) * (NSDecimalNumber(value: 100_000_00) as Decimal)
    
    paymentToSend?.1 = Tokens((number as NSDecimalNumber).doubleValue)
  }
}

// MARK: - NSViewController
extension SendOnChainViewController {
  // FIXME: - make this show a currency thing
  /** Set currency
   */
  func setCurrency(_ sender: NSMenuItem) {
    print("SET CURRENCY \(sender)")
  }
}
