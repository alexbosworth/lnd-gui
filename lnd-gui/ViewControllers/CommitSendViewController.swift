//
//  CommitSendViewController.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 5/7/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Cocoa

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
    guard let paymentToSend = paymentToSend else {
      return print("ERROR", "expected payment")
    }
    
    commitSend(paymentToSend)
  }

  // MARK: - @IBOutlets
  
  /** Button to clear the current payment details.
   */
  @IBOutlet weak var clearPaymentButton: NSButton?
  
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
  var paymentToSend: Payment? { didSet { updatedPaymentRequest() } }
}

extension CommitSendViewController {
  /** Update payment request
   */
  fileprivate func updatedPaymentRequest() {
    guard let payment = paymentToSend else { return }

    let amount: Tokens
    let destination: String
    let fee: Tokens
    let settlementTimeString: String
    
    switch payment {
    case .chainSend(let address, let tokens):
      amount = tokens
      destination = address
      fee = 225
      settlementTimeString = "10-20 min"
      
    case .paymentRequest(let paymentRequest):
      amount = paymentRequest.tokens
      destination = paymentRequest.destination.hexEncoded
      fee = Tokens()
      settlementTimeString = "Instant"
    }
    
    sendToPublicKeyTextField?.stringValue = destination
    sendAmountTextField?.stringValue = "\(amount.formatted) tBTC"
    sendFeeTextField?.stringValue = fee > Tokens() ? "\(fee.formatted) tBTC" : "Free"
    sendSettlementTimeTextField?.stringValue = settlementTimeString
    sendButton?.stringValue = "Send Payment"
    sendButton?.state = NSOnState
    sendButton?.isEnabled = true
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
