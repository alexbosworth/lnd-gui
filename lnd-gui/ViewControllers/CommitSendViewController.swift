//
//  CommitSendViewController.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 5/7/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Cocoa

/** Commit send view controller
 
 FIXME: - add a way to set the fee
 */
class CommitSendViewController: NSViewController {
  // MARK: - @IBActions
  
  /** pressedClearButton triggers a reset on the send form to remove input.
   */
  @IBAction func pressedClearButton(_ button: NSButton) {
    clearDestination()
  }
  
  /** pressedSendButton triggers a send.
   */
  @IBAction func pressedSendButton(_ button: NSButton) {
    guard let paymentToSend = paymentToSend else { return reportError(Failure.expectedPaymentToSend) }
    
    commitSend(paymentToSend)
  }

  // MARK: - @IBOutlets
  
  /** Button to clear the current payment details.
   */
  @IBOutlet weak var clearPaymentButton: NSButton?

  /** Destination label
   */
  @IBOutlet weak var destinationLabel: NSTextField?

  /** Label for payment amount
   */
  @IBOutlet weak var paymentAmountLabel: NSTextField?
  
  /** Payment box
   */
  @IBOutlet weak var paymentBox: NSBox?
  
  /** sendAmountTextField is the label for the payment invoice amount.
   */
  @IBOutlet weak var sendAmountTextField: NSTextField?
  
  /** sendButton is the button that triggers sending.
   */
  @IBOutlet weak var sendButton: NSButton?
  
  /** Send fee text field
   */
  @IBOutlet weak var sendFeeTextField: NSTextField?

  /** Send settlement time text field
   */
  @IBOutlet weak var sendSettlementTimeTextField: NSTextField?
  
  /** sendToPublicKeyTextField is the label for the payment invoice public key.
   */
  @IBOutlet weak var sendToPublicKeyTextField: NSTextField?

  // MARK: - Properties
  
  /** Commit send
   */
  lazy var commitSend: (Payment) -> () = { _ in }

  /** Completed send
   */
  lazy var clearDestination: () -> () = {}
  
  /** Is currently sending
   */
  var isSending = false { didSet { updatedSendingState() } }
  
  /** Payment to send
   */
  var paymentToSend: Payment? { didSet { do { try updatedInvoice() } catch { reportError(error) } } }

  /** Report error
   */
  lazy var reportError: (Error) -> () = { _ in }
  
  /** Wallet
   */
  var wallet: Wallet?
}

// MARK: - Errors
extension CommitSendViewController {
  /** Failures
   */
  enum Failure: Error {
    case expectedLocalBalance
    case expectedPaymentToSend
    case expectedWalletForBalanceCheck
  }
}

// MARK: - NSViewController
extension CommitSendViewController {
  /** Update payment request
   */
  fileprivate func updatedInvoice() throws {
    guard let wallet = wallet else {
      sendAmountTextField?.stringValue = String()
      sendFeeTextField?.stringValue = String()
      sendSettlementTimeTextField?.stringValue = String()
      sendButton?.state = NSOnState
      sendButton?.isEnabled = false
      sendButton?.title = "Send Payment"

      return
    }
    
    guard let payment = paymentToSend else { return }

    let amount: Tokens
    let destination: String
    let localBalance: Tokens
    let fee: Tokens
    let settlementTimeString: String
    
    switch payment {
    case .chainSend(let chainSend):
      amount = chainSend.tokens
      destination = chainSend.address
      destinationLabel?.stringValue = "Chain Address"
      fee = 225
      localBalance = (wallet.balances?.spendableBalance ?? Tokens()) as Tokens
      settlementTimeString = "10-20 min"
      
    case .invoice(let invoice):
      amount = invoice.tokens
      destination = (invoice.destination?.hexEncoded ?? String()) as String
      destinationLabel?.stringValue = "Lightning Address"
      fee = Tokens()
      localBalance = (wallet.balances?.channelTokens ?? Tokens()) as Tokens
      settlementTimeString = "Instant"
    }
    
    let feeAmount: String
    let payAmount: String
    
    if let centsPerCoin = wallet.centsPerCoin {
      feeAmount = try fee.converted(to: .testUnitedStatesDollars, with: centsPerCoin)
      payAmount = try amount.converted(to: .testUnitedStatesDollars, with: centsPerCoin)
    } else {
      feeAmount = String()
      payAmount = String()
    }
    
    sendToPublicKeyTextField?.toolTip = destination
    
    sendToPublicKeyTextField?.attributedStringValue = NSAttributedString(
      string: destination,
      attributes: [NSFontAttributeName: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: NSFontWeightRegular)]
    )
    
    sendAmountTextField?.stringValue = "\(amount.formatted(with: .testBitcoin))\(payAmount)"
    sendFeeTextField?.stringValue = fee > Tokens() ? "\(fee.formatted(with: .testBitcoin)) \(feeAmount)" : "Free"
    sendSettlementTimeTextField?.stringValue = settlementTimeString
    sendButton?.state = NSOnState
    sendButton?.isEnabled = true
    sendButton?.title = "Send Payment"
    
    if localBalance < amount + fee {
      sendButton?.state = NSOffState
      sendButton?.isEnabled = false
      sendButton?.title = "Send Payment (Amount Exceeds Balance)"
    }
  }
  
  /** Updated sending state
   */
  func updatedSendingState() {
    clearPaymentButton?.isEnabled = !isSending
    sendButton?.isEnabled = !isSending
    sendButton?.state = isSending ? NSOffState : NSOnState
    sendButton?.title = isSending ? "Sending..." : "Send Payment"
  }
}

extension CommitSendViewController: WalletListener {
  func walletUpdated() {
    do { try updatedInvoice() } catch { reportError(error) }
  }
}
