//
//  SendViewController.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 3/5/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Cocoa

protocol ErrorReporting {
  var reportError: (Error) -> () { get set }
}

/** SendViewController is a view controller for performing a send.
 
 FIXME: - don't allow sending to yourself
 FIXME: - auto detect sending to a blockchain address
 FIXME: - remember who you send to and confirm on first send that you are sending to a new sender
 FIXME: - allow editing labels and images for senders
 FIXME: - show issue when trying to send more money than is available
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
  
  var centsPerCoin: (() -> (Int?))?

  fileprivate var currencyType: CurrencyType = .testBitcoin
  
  /** Commit send view controller
   */
  fileprivate var commitSendViewController: CommitSendViewController?

  /** Report error
   */
  lazy var reportError: (Error) -> () = { _ in }
  
  /** Send on chain view controller
  */
  fileprivate var sendOnChainViewController: SendOnChainViewController?
  
  var walletTokenBalance: (() -> (Tokens?))?
  
  /** Update balance closure
   */
  lazy var updateBalance: (() -> ()) = {}
}

extension SendViewController {
  enum Failure: Error {
    case expectedCommitSendViewController
    case expectedSendOnChainController
    case unknownSegue
  }
}

// MARK: - Navigation
extension SendViewController {
  /** Prepare for segue. These segues setup container view controllers that show payment specific details.
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
      
      commitSendViewController.centsPerCoin = { [weak self] in self?.centsPerCoin?() }
      commitSendViewController.clearDestination = { [weak self] in self?.resetDestination() }
      commitSendViewController.commitSend = { [weak self] payment in self?.send(payment) }
      commitSendViewController.paymentToSend = nil
      commitSendViewController.reportError = { [weak self] error in self?.reportError(error) }
      commitSendViewController.walletTokenBalance = { [weak self] in self?.walletTokenBalance?() }
      
    case .sendOnChain:
      guard let sendOnChainViewController = destinationController as? SendOnChainViewController else {
        return reportError(Failure.expectedSendOnChainController)
      }
      
      self.sendOnChainViewController = sendOnChainViewController
    
      sendOnChainViewController.centsPerCoin = { [weak self] in self?.centsPerCoin?() }
      sendOnChainViewController.clear = { [weak self] in self?.resetDestination() }
      sendOnChainViewController.reportError = { [weak self] error in self?.reportError(error) }
      sendOnChainViewController.send = { [weak self] payment in self?.send(payment) }
      sendOnChainViewController.walletTokenBalance = { [weak self] in self?.walletTokenBalance?() }
    }
  }
  
  /** Reset payment destination
   */
  fileprivate func resetDestination() {
    destinationTextField?.stringValue = String()
    
    sendOnChainViewController?.paymentToSend = nil
    
    [sendOnChainContainerView, sendChannelPaymentContainerView, sentStatusTextField].forEach { $0?.isHidden = true }
  }

  /** Segue types
   */
  private enum Segue: String {
    case sendChannelPayment = "SendChannelPaymentSegue"
    case sendOnChain = "SendOnChainSegue"
    
    /** Derive segue from StoryboardSegue
     */
    init?(from segue: NSStoryboardSegue) {
      if let id = segue.identifier, let s = type(of: self).init(rawValue: id) { self = s } else { return nil }
    }
  }
}

// MARK: - NSViewController
extension SendViewController {
  override func viewDidAppear() {
    super.viewDidAppear()
    
    if centsPerCoin == nil {
      print("CENTS PER COIN METHOD UNDEFINED")
    }
  }
  
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
  }
}

extension SendViewController {
  /** Show decoded payment request
   */
  private func showDecodedPaymentRequest(_ data: Data, for paymentRequest: String) {
    let payReq: LightningPayment
    
    do { payReq = try LightningPayment(from: data, paymentRequest: paymentRequest) } catch { return reportError(error) }
    
    sendChannelPaymentContainerView?.isHidden = false
    
    guard let commitVc = commitSendViewController else { return reportError(Failure.expectedCommitSendViewController) }
    
    commitVc.paymentToSend = .paymentRequest(payReq)
  }
  
  /** Get decoded payment request
   // FIXME: - see if this can be done natively
   */
  func getDecoded(paymentRequest: SerializedPaymentRequest) throws {
    try Daemon.get(from: Daemon.Api.paymentRequest(paymentRequest)) { [weak self] result in
      switch result {
      case .data(let data):
        self?.showDecodedPaymentRequest(data, for: paymentRequest)

      case .error(let error):
        self?.reportError(error)
      }
    }
  }
}

extension SendViewController {
  /** Send payment
   */
  fileprivate func send(_ payment: Payment) {
    commitSendViewController?.isSending = true
    
    switch payment {
    case .chainSend(let chainSend):
      send(chainSend)
      
    case .paymentRequest(let paymentRequest):
      do { try send(paymentRequest) } catch { reportError(error) }
    }
  }
  
  /** Send payment on chain
   */
  private func showSendOnChainResult(tokens: Tokens) {
    resetDestination()

    sentStatusTextField?.isHidden = false
    sentStatusTextField?.stringValue = "Sending \(tokens.formatted(with: .testBitcoin))."
  }
  
  private func send(_ chainSend: ChainSend) {
    enum SendOnChainJsonAttribute: String {
      case address
      case tokens
      
      var key: String { return rawValue }
    }

    let json: [String: Any] = [
      SendOnChainJsonAttribute.address.key: chainSend.address,
      SendOnChainJsonAttribute.tokens.key: chainSend.tokens,
    ]
    
    do {
      try Daemon.send(json: json, to: .transactions) { [weak self] result in
        DispatchQueue.main.async {
          switch result {
          case .error(let error):
            self?.reportError(error)
            
          case .success:
            self?.showSendOnChainResult(tokens: chainSend.tokens)
          }
        }
      }
    } catch {
      reportError(error)
    }
  }
  
  /** Show payment result
   */
  private func showPaymentResult(payment: LightningPayment, start: Date) {
    sendChannelPaymentContainerView?.isHidden = true
    commitSendViewController?.paymentToSend = nil
    destinationTextField?.stringValue = String()
    
    // FIXME: - show settled transaction
    let sentAmount = payment.tokens.formatted(with: .testBitcoin)
    let duration = Date().timeIntervalSince(start)
    sentStatusTextField?.isHidden = false
    sentStatusTextField?.stringValue = "Sent \(sentAmount) in \(String(format: "%.2f", duration)) seconds."
    
    guard let centsPerCoin = centsPerCoin?() else { return }
    
    do {
      let converted = try payment.tokens.converted(to: .testUnitedStatesDollars, with: centsPerCoin)

      sentStatusTextField?.stringValue = "Sent \(sentAmount)\(converted) in \(String(format: "%.2f", duration)) seconds."
    } catch {
      reportError(error)
    }
  }
  
  private func send(_ payment: LightningPayment) throws {
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
    
    guard let serializedPaymentRequest = payment.serializedPaymentRequest else { return }
    
    let json: JsonDictionary = [SendPaymentJsonAttribute.paymentRequest.key: serializedPaymentRequest]
    
    try Daemon.send(json: json, to: .payments) { [weak self] result in
      self?.commitSendViewController?.isSending = false
      
      switch result {
      case .error(let error):
        self?.reportError(error)
        
        NSAlert(error: error).runModal()
        
      case .success:
        self?.showPaymentResult(payment: payment, start: start)
      }
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
    sendOnChainContainerView?.isHidden = true
    sentStatusTextField?.isHidden = true
    
    guard let destination = destinationTextField?.stringValue, !destination.isEmpty else { return }
    
    if destination.hasPrefix("2") || destination.hasPrefix("m") {
      sendOnChainContainerView?.isHidden = false

      let tokens: Tokens = (sendOnChainViewController?.paymentToSend?.tokens ?? Tokens()) as Tokens
      
      sendOnChainViewController?.paymentToSend = ChainSend(address: destination, tokens: tokens)
      
      return
    }
    
    sendOnChainViewController?.paymentToSend = nil
    
    sendOnChainContainerView?.isHidden = true
    
    do { try getDecoded(paymentRequest: destination) } catch { reportError(error) }
  }
}

extension SendViewController: WalletListener {
  func wallet(updated: Wallet) {
    commitSendViewController?.wallet(updated: updated)
  }
}
