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
  FIXME: - fiat entry does not match up with fiat conversion
 */
class SendOnChainViewController: NSViewController {
  // MARK: - @IBActions
  
  /** Pressed amount options button
   */
  @IBAction func pressedAmountOptionsButton(_ button: NSPopUpButton) {
    guard let currencyTypeMenuItem = button.selectedItem as? CurrencyTypeMenuItem else {
      return reportError(Failure.expectedCurrencyTypeMenuItem)
    }
    
    currencyType = currencyTypeMenuItem.currencyType
  }
  
  // MARK: - @IBOutlets
  
  /** Embedded commit view
   */
  @IBOutlet weak var commitSendView: NSView?

  /** Number of tokens to send
   */
  @IBOutlet weak var tokensToSendTextField: NSTextField?
  
  // MARK: - Properties
  
  /** Cents per coin
   */
  var centsPerCoin: (() -> (Int?))?

  /** Clear send
   */
  lazy var clear: () -> () = {}
  
  /** Confirm send view
   */
  fileprivate weak var commitSendViewController: CommitSendViewController?

  /** Currency type selected for amount input
   */
  var currencyType: CurrencyType = .testBitcoin { didSet { updatePaymentToSendFromInput() } }
  
  /** Payment to send

   FIXME: - make into struct
   */
  var paymentToSend: ChainSend? { didSet { updatedPaymentToSend() } }
  
  /** Report error
   */
  lazy var reportError: (Error) -> () = { _ in }

  /** Commit send
   */
  lazy var send: (Payment) -> () = { _ in }
  
  var walletTokenBalance: (() -> (Tokens?))?
}

// MARK: - Failures
extension SendOnChainViewController {
  /** Failures
   */
  enum Failure: Error {
    case expectedCurrencyTypeMenuItem
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
    commitSendViewController.walletTokenBalance = { [weak self] in self?.walletTokenBalance?() }
    commitSendViewController.reportError = { [weak self] error in self?.reportError(error) }
  }
}

// MARK: - NSTextFieldDelegate
extension SendOnChainViewController: NSTextFieldDelegate {
  func updatePaymentToSendFromInput() {
    guard let existingChainSend = paymentToSend else { return }
    
    paymentToSend = ChainSend(address: existingChainSend.address, tokens: Tokens())
    
    guard let amountString = tokensToSendTextField?.stringValue else { return }
    
    let tokens: Tokens
    
    switch currencyType {
    case .testBitcoin:
      tokens = Tokens(from: amountString)
      
    case .testUnitedStatesDollars:
      guard let centsPerCoin = centsPerCoin?() else { tokens = Tokens(); break }
      
      tokens = Tokens(from: amountString) / Tokens(centsPerCoin / 100)
    }
    
    paymentToSend = ChainSend(address: existingChainSend.address, tokens: tokens)
  }
  
  /** Control text did change
   */
  override func controlTextDidChange(_ obj: Notification) {
    updatePaymentToSendFromInput()
  }
}

// MARK: - NSViewController
extension SendOnChainViewController {
  /** Updated payment to send
   */
  fileprivate func updatedPaymentToSend() {
    guard let paymentToSend = paymentToSend else {
      commitSendViewController?.paymentToSend = nil
      tokensToSendTextField?.stringValue = String()
      return
    }
    
    commitSendViewController?.paymentToSend = .chainSend(paymentToSend)
  }
}
