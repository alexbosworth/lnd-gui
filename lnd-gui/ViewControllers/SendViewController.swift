//
//  SendViewController.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 3/5/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Cocoa

protocol ErrorReporting {
  var reportError: (Error) -> () { get }
}

/** SendViewController is a view controller for performing a send.
 
 FIXME: - auto detect sending to a blockchain address
 FIXME: - don't allow sending to yourself
 FIXME: - remember who you send to and confirm on first send that you are sending to a new sender
 FIXME: - allow editing labels and images for senders
 */
class SendViewController: NSViewController, ErrorReporting {
  // MARK: - @IBOutlets
  
  /** destinationTextField is the input for payment destination entry.
   */
  @IBOutlet weak var destinationTextField: NSTextField?

  /** Send on chain container view
   */
  @IBOutlet weak var sendOnChainContainerView: NSView?

  /** Send channel payment container view
   */
  @IBOutlet weak var sendChannelPaymentContainerView: NSView?
  
  /** Sent status text field
   */
  @IBOutlet weak var sentStatusTextField: NSTextField?

  /** Sent transaction container view
   */
  @IBOutlet weak var sentTransactionContainerView: NSView?
  
  // MARK: - Properties
  
  /** Commit send view controller
   */
  fileprivate var commitSendViewController: CommitSendViewController?

  /** Report error
   */
  lazy var reportError: (Error) -> () = { _ in }
  
  /** Send on chain view controller
  */
  fileprivate var sendOnChainViewController: SendOnChainViewController?

  /** Sent transaction view controller
   */
  fileprivate var sentTransactionViewController: SentTransactionViewController?
  
  var settledTransaction: Transaction? { didSet { updatedSettledTransaction() } }
  
  /** Update balance closure
   */
  lazy var updateBalance: (() -> ()) = {}
}

extension SendViewController {
  enum Failure: Error {
    case expectedCommitSendViewController
    case expectedSendOnChainController
    case expectedSentTransactionViewController
    case unknownSegue
  }
}

// MARK: - Navigation
extension SendViewController {
  /** Prepare for segue
   */
  override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
    let destinationController = segue.destinationController
    
    guard let segue = Segue(from: segue) else { return reportError(Failure.unknownSegue) }
    
    switch segue {
    case .sendChannelPayment:
      guard let commitSendViewController = destinationController as? CommitSendViewController else {
        return reportError(Failure.expectedCommitSendViewController)
      }
      
      self.commitSendViewController = commitSendViewController
      
      commitSendViewController.clearDestination = { [weak self] in self?.resetDestination() }
      commitSendViewController.commitSend = { [weak self] payment in self?.send(payment) }
      commitSendViewController.paymentToSend = nil
      commitSendViewController.reportError = { [weak self] error in self?.reportError(error) }
      
    case .sendOnChain:
      guard let sendOnChainViewController = destinationController as? SendOnChainViewController else {
        return reportError(Failure.expectedSendOnChainController)
      }
      
      self.sendOnChainViewController = sendOnChainViewController
      
      sendOnChainViewController.clear = { [weak self] in self?.resetDestination() }
      sendOnChainViewController.reportError = { [weak self] error in self?.reportError(error) }
      sendOnChainViewController.send = { [weak self] payment in self?.send(payment) }
      
    case .sentTransaction:
      guard let sentTransactionViewController = destinationController as? SentTransactionViewController else {
        return reportError(Failure.expectedSentTransactionViewController)
      }

      sentTransactionViewController.reportError = { [weak self] error in self?.reportError(error) }
      
      self.sentTransactionViewController = sentTransactionViewController
    }
  }
  
  /** Reset payment destination
   */
  fileprivate func resetDestination() {
    destinationTextField?.stringValue = String()
    
    sendOnChainViewController?.paymentToSend = nil
    
    [sendOnChainContainerView, sendChannelPaymentContainerView, sentStatusTextField].forEach { $0?.isHidden = true }
  }

  /** Segues
   */
  private enum Segue: String {
    case sendChannelPayment = "SendChannelPaymentSegue"
    case sendOnChain = "SendOnChainSegue"
    case sentTransaction = "SentTransactionSegue"
    
    init?(from segue: NSStoryboardSegue) {
      if let id = segue.identifier, let s = type(of: self).init(rawValue: id) { self = s } else { return nil }
    }
  }
  
  fileprivate func updatedSettledTransaction() {
    guard let transaction = settledTransaction else {
      sentTransactionContainerView?.isHidden = true
      
      return
    }

    sentTransactionContainerView?.isHidden = false
    sentTransactionViewController?.settledTransaction = transaction
  }
}

// MARK: - NSViewController
extension SendViewController {
  /** View did load
   */
  override func viewDidLoad() {
    super.viewDidLoad()

//    destinationTextField?.formatter = OnlyValidPaymentRequestValueFormatter()
  }
  
  /** View will disappear
   */
  override func viewWillDisappear() {
    super.viewWillDisappear()
    
    sentStatusTextField?.isHidden = true
    
    settledTransaction = nil
  }
}

extension SendViewController {
  private func showDecodedPaymentRequest(_ data: Data, for paymentRequest: String) {
    let payReq: PaymentRequest
    
    do { payReq = try PaymentRequest(from: data, paymentRequest: paymentRequest) } catch { return reportError(error) }
    
    sendChannelPaymentContainerView?.isHidden = false
    
    guard let commitVc = commitSendViewController else { return reportError(Failure.expectedCommitSendViewController) }
    
    commitVc.paymentToSend = .paymentRequest(payReq)
  }
  
  // FIXME: - see if this can be done natively
  // FIXME: - abstract to Daemon
  func getDecoded(paymentRequest: String) {
    do {
      try Daemon.get(from: Daemon.Api.paymentRequest(paymentRequest)) { [weak self] result in
        switch result {
        case .data(let data):
          self?.showDecodedPaymentRequest(data, for: paymentRequest)

        case .error(let error):
          self?.reportError(error)
        }
      }
    } catch {
      reportError(error)
    }
  }
}

extension SendViewController {
  // FIXME: - abstract to Daemon
  fileprivate func send(_ payment: Payment) {
    commitSendViewController?.isSending = true
    
    switch payment {
    case .chainSend(let address, let tokens):
      send(to: address, tokens: tokens)
      
    case .paymentRequest(let paymentRequest):
      send(paymentRequest)
    }
  }
  
  // FIXME: - need a link to the transaction here
  private func showSendOnChainResult(tokens: Tokens) {
    resetDestination()

    sentStatusTextField?.isHidden = false
    sentStatusTextField?.stringValue = "Sending \(tokens.formatted) tBTC."
  }
  
  private func send(to address: String, tokens: Tokens) {
    enum SendOnChainJsonAttribute: String {
      case address
      case tokens
      
      var key: String { return rawValue }
    }

    let json: [String: Any] = [
      SendOnChainJsonAttribute.address.key: address,
      SendOnChainJsonAttribute.tokens.key: tokens,
    ]
    
    do {
      try Daemon.send(json: json, to: .transactions) { [weak self] result in
        DispatchQueue.main.async {
          switch result {
          case .error(let error):
            self?.reportError(error)
            
          case .success:
            self?.showSendOnChainResult(tokens: tokens)
          }
        }
      }
    } catch {
      reportError(error)
    }
  }
  
  private func showPaymentResult(payment: PaymentRequest, start: Date) {
    sendChannelPaymentContainerView?.isHidden = true
    commitSendViewController?.paymentToSend = nil
    destinationTextField?.stringValue = String()
    
    // FIXME: - show settled transaction
    let duration = Date().timeIntervalSince(start)
    sentStatusTextField?.isHidden = false
    sentStatusTextField?.stringValue = "Sent \(payment.tokens.formatted) tBTC in \(String(format: "%.2f", duration)) seconds."
  }
  
  private func send(_ paymentRequest: PaymentRequest) {
    let start = Date()
    
    enum SendPaymentJsonAttribute: String {
      case paymentRequest
      
      var key: String {
        switch self {
        case .paymentRequest:
          return "payment_request"
        }
      }
    }
    
    let json: [String: Any] = [SendPaymentJsonAttribute.paymentRequest.key: paymentRequest.paymentRequest]
    
    do {
      try Daemon.send(json: json, to: .payments) { [weak self] result in
        self?.commitSendViewController?.isSending = false
        
        switch result {
        case .error(let error):
          self?.reportError(error)
          
        case .success:
          self?.showPaymentResult(payment: paymentRequest, start: start)
        }
      }
    } catch {
      reportError(error)
    }
  }
}

extension SendViewController {
  // FIXME: - Abstract
  class OnlyValidPaymentRequestValueFormatter: NumberFormatter {
    override func isPartialStringValid(_ partialString: String, newEditingString newString: AutoreleasingUnsafeMutablePointer<NSString?>?, errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool {
      guard !partialString.isEmpty else { return true }
      
      guard let _ = URL(string: "http://localhost:10553/v0/payment_request/\(partialString)") else {
        return false
      }
      
      return true
    }
  }
}

// FIXME: - cleanup - localization prep
extension SendViewController: NSTextFieldDelegate {
  /** Control text did change
   */
  override func controlTextDidChange(_ obj: Notification) {
    commitSendViewController?.paymentToSend = nil

    sendChannelPaymentContainerView?.isHidden = true
    
    guard let destination = destinationTextField?.stringValue else {
      return
    }
    
    sentStatusTextField?.isHidden = true

    if destination.hasPrefix("2") || destination.hasPrefix("m") {
      sendOnChainContainerView?.isHidden = false
      sendOnChainViewController?.paymentToSend = (destination, Tokens())
      
      return
    }
    
    sendOnChainViewController?.paymentToSend = nil
    
    sendOnChainContainerView?.isHidden = true
    
    getDecoded(paymentRequest: destination)
  }
}
