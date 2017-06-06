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
  @IBAction func pressedAmountOptionsButton(_ button: NSButton) {
    showCurrencySelector(from: button)
  }
  
  // MARK: - @IBOutlets
  
  /** Embedded commit view
   */
  @IBOutlet weak var commitSendView: NSView?

  /** Number of tokens to send
   */
  @IBOutlet weak var tokensToSendTextField: NSTextField?
  
  // MARK: - Properties
  
  var centsPerCoin: (() -> (Int?))?

  /** Clear send
   */
  lazy var clear: () -> () = {}
  
  /** Confirm send view
   */
  fileprivate weak var commitSendViewController: CommitSendViewController?

  /** Payment to send

   FIXME: - make into struct
   */
  var paymentToSend: (String, Tokens)? { didSet { updatedPaymentToSend() } }
  
  /** Report error
   */
  lazy var reportError: (Error) -> () = { _ in }

  /** Commit send
   */
  lazy var send: (Payment) -> () = { _ in }
}

// MARK: - Failures
extension SendOnChainViewController {
  /** Failures
   */
  enum Failure: Error {
    case expectedCurrentEvent
    case expectedViewController
    case unexpectedSegue
  }
}

// MARK: - Navigation
extension SendOnChainViewController {
  /** Storyboard segue
   */
  enum Segue: StoryboardIdentifier {
    case previewSend = "PreviewChainSendSegue"
    
    /** Create from segue
     */
    init?(from segue: NSStoryboardSegue) {
      if let id = segue.identifier, let segue = type(of: self).init(rawValue: id) { self = segue } else { return nil }
    }
  }
  
  /** Prepare for segue
   */
  override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
    guard let commitSendViewController = segue.destinationController as? CommitSendViewController else {
      return reportError(Failure.expectedViewController)
    }
    
    guard let _ = Segue(from: segue) else { return reportError(Failure.unexpectedSegue) }
    
    self.commitSendViewController = commitSendViewController
    
    commitSendViewController.centsPerCoin = { [weak self] in self?.centsPerCoin?() }
    commitSendViewController.clearDestination = { [weak self] in self?.clear() }
    commitSendViewController.commitSend = { [weak self] payment in self?.send(payment) }
    commitSendViewController.reportError = { [weak self] error in self?.reportError(error) }
  }

  /** Show currency selector menu
   */
  fileprivate func showCurrencySelector(from button: NSButton) {
    guard let event = NSApplication.shared().currentEvent else { return reportError(Failure.expectedCurrentEvent) }
    
    let menu = NSMenu(title: NSLocalizedString("Currency", comment: "Currency selection menu title"))
    
    [Currency.testBitcoin, .testUnitedStatesDollars].forEach { currency in
      menu.addItem(withTitle: currency.symbol, action: #selector(setCurrency(_:)), keyEquivalent: String())
    }
    
    menu.items.forEach { $0.target = self }
    
    NSMenu.popUpContextMenu(menu, with: event, for: button)
  }
}

// MARK: - NSTextFieldDelegate
extension SendOnChainViewController: NSTextFieldDelegate {
  /** Control text did change
   */
  override func controlTextDidChange(_ obj: Notification) {
    paymentToSend?.1 = Tokens()
    
    guard let amountString = tokensToSendTextField?.stringValue else { return }
    
    paymentToSend?.1 = Tokens(from: amountString)
  }
}

// MARK: - NSViewController
extension SendOnChainViewController {
  /** Set currency
   */
  func setCurrency(_ sender: NSMenuItem) {
    // FIXME: - make this show a currency thing
    print("SET CURRENCY \(sender)")
  }
  
  /** Updated payment to send
   */
  fileprivate func updatedPaymentToSend() {
    guard let paymentToSend = paymentToSend else {
      commitSendViewController?.paymentToSend = nil
      tokensToSendTextField?.stringValue = String()
      return
    }
    
    commitSendViewController?.paymentToSend = .chainSend(paymentToSend.0, paymentToSend.1)
  }
}
