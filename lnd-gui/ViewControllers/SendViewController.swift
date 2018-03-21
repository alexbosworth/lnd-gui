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

  /** Selected currency type
   */
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
  
  /** Showing invoice
   */
  var showInvoice: SerializedInvoice?
  
  /** Wallet
   */
  var wallet: Wallet? {
    didSet {
      sendOnChainViewController?.wallet = wallet
    }
  }
}

extension SendViewController {
  enum Failure: Error {
    case expectedCommitSendViewController
    case expectedSendOnChainController
    case expectedWallet
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
      sendOnChainViewController.wallet = wallet
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
    
    // Exit early when the invoice did not change
    guard let invoice = self.showInvoice else { return }
    
    destinationTextField?.stringValue = invoice
      
    didChangeDestination()
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
  private func showDecodedInvoice(_ data: Data, for serializedInvoice: SerializedInvoice) {
    let invoice: LightningPayment
    
    // Exit early on errors on payment request decoding.
    do { invoice = try LightningPayment(from: data, invoice: serializedInvoice) } catch { return }
    
    sendChannelPaymentContainerView?.isHidden = false
    
    guard let commitVc = commitSendViewController else { return reportError(Failure.expectedCommitSendViewController) }

    commitVc.wallet = wallet
    
    commitVc.paymentToSend = .invoice(invoice)
  }
  
  /** Get decoded payment request
   // FIXME: - see if this can be done natively
   */
  func getDecoded(invoice: SerializedInvoice) throws {
    try Daemon.get(from: Daemon.Api.invoices(invoice)) { [weak self] result in
      switch result {
      case .data(let data):
        self?.showDecodedInvoice(data, for: invoice)

      // Errors are expected since we don't know if the payment request is valid.
      case .error(_):
        break
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
      
    case .invoice(let invoice):
      do { try send(invoice) } catch { reportError(error) }
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
            NSAlert(error: error).runModal()
            
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
   
   FIXME: - show this differently
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
    
    guard let centsPerCoin = wallet?.centsPerCoin else { return }
    
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
      case invoice
      
      var key: String { return rawValue }
    }
    
    guard let serializedInvoice = payment.serializedInvoice else { return }
    
    let json: JsonDictionary = [SendPaymentJsonAttribute.invoice.key: serializedInvoice]
    
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
  class OnlyValidInvoiceValueFormatter: NumberFormatter {
    override func isPartialStringValid(_ partialString: String, newEditingString newString: AutoreleasingUnsafeMutablePointer<NSString?>?, errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool {
      guard !partialString.isEmpty else { return true }
      
      guard let _ = URL(string: "http://localhost:10553/v0/invoice/\(partialString)") else {
        return false
      }
      
      return true
    }
  }
}

// FIXME: - cleanup - localization prep
// MARK: - NSTextFieldDelegate
extension SendViewController: NSTextFieldDelegate {
  func didChangeDestination() {
    guard let wallet = wallet else {
      return reportError(Failure.expectedWallet)
    }
    
    commitSendViewController?.paymentToSend = nil
    
    sendChannelPaymentContainerView?.isHidden = true
    sendOnChainContainerView?.isHidden = true
    sentStatusTextField?.isHidden = true
    
    guard let destination = destinationTextField?.stringValue, !destination.isEmpty else { return }
    
    if destination.hasPrefix("2") || destination.hasPrefix("m") {
      sendOnChainContainerView?.isHidden = false
      sendOnChainViewController?.wallet = wallet
      
      let tokens: Tokens = (sendOnChainViewController?.paymentToSend?.tokens ?? Tokens()) as Tokens
      
      sendOnChainViewController?.paymentToSend = ChainSend(address: destination, tokens: tokens)
      
      return
    }
    
    sendOnChainViewController?.paymentToSend = nil
    
    sendOnChainContainerView?.isHidden = true
    
    // Swallow errors on get decoded, it is expected the destination may be invalid
    do { try getDecoded(invoice: destination) } catch {}
  }
  
  /** Control text did change
   */
  override func controlTextDidChange(_ obj: Notification) {
    didChangeDestination()
  }
}

// MARK: - WalletListener
extension SendViewController: WalletListener {
  func walletUpdated() {
    guard let wallet = wallet else { return }
    
    commitSendViewController?.wallet = wallet
    commitSendViewController?.walletUpdated()
    
    sendOnChainViewController?.wallet = wallet
    sendOnChainViewController?.walletUpdated()
  }
}
