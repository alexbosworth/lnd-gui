//
//  SendViewController.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 3/5/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Cocoa

/** SendViewController is a view controller for performing a send.
 */
class SendViewController: NSViewController {
  // MARK: - @IBActions

  /** pressedClearButton triggers a reset on the send form to remove input.
   */
  @IBAction func pressedClearButton(_ button: NSButton) {
    clear()
  }
  
  /** pressedSendButton triggers a send.
   */
  @IBAction func pressedSendButton(_ button: NSButton) {
    sendCoins()
  }
  
  // MARK: - @IBOutlets
  
  /** clearPaymentButton clears the current payment details.
   */
  @IBOutlet weak var clearPaymentButton: NSButton?
  
  /** iconImageView represents the send destination with an icon image.
   */
  @IBOutlet weak var iconImageView: NSImageView?
  
  /** destinationTextField is the input for payment destination entry.
   */
  @IBOutlet weak var destinationTextField: NSTextField?
  
  /** paymentHeadingTextField is the label for the payment invoice heading.
   */
  @IBOutlet weak var paymentHeadingTextField: NSTextField?
  
  /** sendToPublicKeyTextField is the label for the payment invoice public key.
   */
  @IBOutlet weak var sendToPublicKeyTextField: NSTextField?
  
  /** sendForPaymentTextField is the label for the payment invoice id.
   */
  @IBOutlet weak var sendForPaymentTextField: NSTextField?
  
  /** sendAmountTextField is the label for the payment invoice amount.
   */
  @IBOutlet weak var sendAmountTextField: NSTextField?
  
  /** sendButton is the button that triggers sending.
   */
  @IBOutlet weak var sendButton: NSButton?
  
  // MARK: - Properties
  
  /** sendAmount is the amount to send.
   */
  fileprivate var sendAmount: Value? {
    didSet {
      guard let sendAmount = sendAmount else { sendAmountTextField?.stringValue = String(); return }
      
      sendAmountTextField?.stringValue = "\(sendAmount.formatted) tBTC"
    }
  }
  
  fileprivate var sendToPublicKey: String? {
    didSet {
      let publicKey = (sendToPublicKey ?? String()) as String
      
      payment(on: !publicKey.isEmpty)
      
      sendToPublicKeyTextField?.stringValue = publicKey
    }
  }
  
  private var sendForPayment: String? {
    didSet {
      sendForPaymentTextField?.stringValue = sendForPayment ?? String()
    }
  }

  private func payment(on: Bool) {
    let shouldBeHidden = on == false
    
    clearPaymentButton?.isHidden = shouldBeHidden
    paymentHeadingTextField?.isHidden = shouldBeHidden
    iconImageView?.isHidden = shouldBeHidden
    sendButton?.isHidden = shouldBeHidden
  }

  var updateBalance: (() -> ())?

  // FIXME: - see if this can be done natively
  func getDecoded(paymentRequest: String) {
    guard let url = URL(string: "http://localhost:10553/v0/payment_request/\(paymentRequest)") else {
      return sendToPublicKey = String()
    }
    
    let session = URLSession.shared
    
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    
    let task = session.dataTask(with: request) { [weak self] data, urlResponse, error in
      guard let paymentRequestData = data else {
        DispatchQueue.main.async {
          self?.sendAmount = 0
          self?.sendForPayment = String()
          self?.sendToPublicKey = String()
        }

        return print("Expected payment request data")
      }
      
      let dataDownloadedAsJson = try? JSONSerialization.jsonObject(with: paymentRequestData, options: .allowFragments)
      
      let paymentRequestJson = dataDownloadedAsJson as? [String: Any]
      
      guard let amount = paymentRequestJson?["amount"] as? NSNumber else {
        return
      }
      
      guard let destinationPublicKey = paymentRequestJson?["destination"] as? String else {
        return
      }
      
      guard let paymentRequestId = paymentRequestJson?["id"] as? String else {
        return
      }
      
      DispatchQueue.main.async {
        self?.sendAmount = amount.uint64Value
        self?.sendForPayment = paymentRequestId
        self?.sendToPublicKey = destinationPublicKey
      }
    }
    
    task.resume()
  }
  
  private func sendCoins() {
    let session = URLSession.shared
    let sendUrl = URL(string: "http://localhost:10553/v0/channels/")!
    var sendUrlRequest = URLRequest(url: sendUrl, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 30)
    sendUrlRequest.httpMethod = "POST"
    sendUrlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let destination = (destinationTextField?.stringValue ?? String()) as String
    
    let data = "{\"payment_request\": \"\(destination)\"}".data(using: .utf8)
    
    sendButton?.isEnabled = false
    sendButton?.state = NSOffState
    sendButton?.title = "Sending"
    
    let sendTask = session.uploadTask(with: sendUrlRequest, from: data) { [weak self] data, urlResponse, error in
      if let error = error {
        return print("ERROR \(error)")
      }
      
      DispatchQueue.main.async {
        self?.updateBalance?()
        
        let sentAmount = self?.sendAmountTextField?.stringValue ?? String()
        let sendToKey = self?.sendToPublicKey ?? String()
        
        let alert = NSAlert.init()
        alert.messageText = "Lightning Payment Sent"
        alert.informativeText = "Sent \(sentAmount) to \(sendToKey)"
        alert.addButton(withTitle: "OK")
        alert.runModal()
        
        self?.sendButton?.isEnabled = true
        self?.sendButton?.state = NSOnState
        self?.sendButton?.title = "Send"
        
        self?.destinationTextField?.stringValue = String()
        self?.sendToPublicKey = String()
        self?.sendAmount = nil
        
        self?.payment(on: false)
      }
    }
    
    sendTask.resume()
  }

  /** clear resets the send input and removes information about a previous send.
   */
  private func clear() {
    destinationTextField?.stringValue = String()
    
    sendButton?.isEnabled = true
    sendButton?.state = NSOnState
    sendButton?.title = "Send"
    
    destinationTextField?.stringValue = String()
    sendToPublicKey = String()
    sendAmount = nil
    
    payment(on: false)
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    // Do view setup here.
    
    iconImageView?.wantsLayer = true
    iconImageView?.layer?.backgroundColor = NSColor.lightGray.cgColor
    iconImageView?.layer?.cornerRadius = 8
    iconImageView?.layer?.masksToBounds = true
    
    sendToPublicKey = String()
  }
}

// FIXME: - cleanup - localization prep
extension SendViewController: NSTextFieldDelegate {
  override func controlTextDidChange(_ obj: Notification) {
    sendAmount = nil
    sendToPublicKey = String()
    
    guard let destination = destinationTextField?.stringValue else { return }
    
    getDecoded(paymentRequest: destination)
  }
}
