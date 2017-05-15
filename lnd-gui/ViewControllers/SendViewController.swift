//
//  SendViewController.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 3/5/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Cocoa

/** SendViewController is a view controller for performing a send.
 
 FIXME: - auto detect sending to a blockchain address
 FIXME: - don't allow sending to yourself
 FIXME: - remember who you send to and confirm on first send that you are sending to a new sender
 FIXME: - allow editing labels and images for senders
 */
class SendViewController: NSViewController {
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

// MARK: - Navigation
extension SendViewController {
  /** Prepare for segue
   */
  override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
    let destinationController = segue.destinationController
    
    guard let segue = Segue(from: segue) else { return print("ERROR", "unknown segue") }
    
    switch segue {
    case .sendChannelPayment:
      guard let commitSendViewController = destinationController as? CommitSendViewController else {
        return print("ERROR", "expected commit send view controller")
      }
      
      self.commitSendViewController = commitSendViewController
      
      commitSendViewController.paymentToSend = nil
      
      commitSendViewController.commitSend = { [weak self] payment in
        self?.send(payment)
      }
      
      commitSendViewController.clearDestination = { [weak self] in self?.resetDestination() }
      
    case .sendOnChain:
      guard let sendOnChainViewController = destinationController as? SendOnChainViewController else {
        return print("ERROR", "expected send on chain view controller")
      }
      
      self.sendOnChainViewController = sendOnChainViewController
      
      sendOnChainViewController.send = { [weak self] payment in self?.send(payment) }
      
      sendOnChainViewController.clear = { [weak self] in self?.resetDestination() }
      
    case .sentTransaction:
      guard let sentTransactionViewController = destinationController as? SentTransactionViewController else {
        return print("ERROR", "expected sent on chain view controller")
      }
      
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
  // FIXME: - see if this can be done natively
  // FIXME: - abstract to Daemon
  func getDecoded(paymentRequest: String) {
    guard let url = URL(string: "http://localhost:10553/v0/payment_request/\(paymentRequest)") else {
      return print("INVALID PAYMENT REQUEST")
    }
    
    let session = URLSession.shared
    
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    
    let task = session.dataTask(with: request) { [weak self] data, urlResponse, error in
      if let error = error {
        return print("DECODE PAYMENT REQUEST ERROR", error)
      }
      
      DispatchQueue.main.async {
        do {
          let payReq = try PaymentRequest(from: data, paymentRequest: paymentRequest)
          
          self?.sendChannelPaymentContainerView?.isHidden = false

          guard let commitSendViewController = self?.commitSendViewController else {
            return print("ERROR", "expected commit send view controller")
          }
          
          commitSendViewController.paymentToSend = .paymentRequest(payReq)
        } catch {
          print("ERROR", error)
        }
      }
    }
    
    task.resume()
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
  
  private func send(to address: String, tokens: Tokens) {
    print("SEND \(address) \(tokens)")
    do {
      try Daemon.send(json: ["address": address, "tokens": tokens], to: .transactions) { [weak self] result in
        DispatchQueue.main.async {
          switch result {
          case .error(let error):
            print("ERROR", error)
            
          case .success:
            self?.resetDestination()
            
            self?.sentStatusTextField?.isHidden = false
            self?.sentStatusTextField?.stringValue = "Sending \(tokens.formatted) tBTC."
          }
        }
      }
    } catch {
      print("ERROR", error)
    }
  }
  
  private func send(_ paymentRequest: PaymentRequest) {
    let start = Date()
    
    do {
      try Daemon.send(json: ["payment_request": paymentRequest.paymentRequest], to: .payments) { [weak self] result in
        DispatchQueue.main.async {
          self?.commitSendViewController?.isSending = false
          
          switch result {
          case .error(let error):
            print("ERROR", error)
            
          case .success:
            self?.sendChannelPaymentContainerView?.isHidden = true
            self?.commitSendViewController?.paymentToSend = nil
            self?.destinationTextField?.stringValue = String()
            
            // FIXME: - show settled transaction
            let duration = Date().timeIntervalSince(start)
            self?.sentStatusTextField?.isHidden = false
            self?.sentStatusTextField?.stringValue = "Sent \(paymentRequest.tokens.formatted) tBTC in \(String(format: "%.2f", duration)) seconds."
          }
        }
      }
    } catch {
      print("ERROR", error)
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
