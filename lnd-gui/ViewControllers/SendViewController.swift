//
//  SendViewController.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 3/5/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Cocoa

class OnlyValidPaymentRequestValueFormatter: NumberFormatter {
  override func isPartialStringValid(_ partialString: String, newEditingString newString: AutoreleasingUnsafeMutablePointer<NSString?>?, errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool {
    guard !partialString.isEmpty else { return true }
    
    guard let _ = URL(string: "http://localhost:10553/v0/payment_request/\(partialString)") else {
      return false
    }
    
    return true
  }
}

struct PaymentRequest: JsonInitialized {
  let destination: PublicKey
  let id: PaymentHash
  let tokens: Tokens
  
  enum JsonAttribute: String {
    case destination
    case id
    case tokens
    
    var asKey: String { return rawValue }
  }
  
  enum ParseJsonFailure: Error {
    case expectedPaymentRequestId
    case expectedPublicKey
    case expectedTokens
  }
  
  init(from data: Data?) throws {
    let json = try type(of: self).jsonDictionaryFromData(data)
    
    guard let hexEncodedDestinationPublicKey = json[JsonAttribute.destination.asKey] as? HexEncodedData else {
      throw ParseJsonFailure.expectedPublicKey
    }
    
    destination = try PublicKey(from: hexEncodedDestinationPublicKey)
    
    guard let paymentRequestId = json[JsonAttribute.id.asKey] as? HexEncodedData else {
      throw ParseJsonFailure.expectedPaymentRequestId
    }
    
    id = try PaymentHash(from: paymentRequestId)
    
    guard let amount = json[JsonAttribute.tokens.asKey] as? NSNumber else { throw ParseJsonFailure.expectedTokens }

    tokens = amount.tokensValue
  }
}

class SendPaymentButton: NSButton {
}

/** SendViewController is a view controller for performing a send.
 
 FIXME: - auto detect sending to a blockchain address
 FIXME: - don't allow sending to yourself
 FIXME: - remember who you send to and confirm on first send that you are sending to a new sender
 FIXME: - allow editing labels and images for senders
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

  /** Label for payment amount
   */
  @IBOutlet weak var paymentAmountLabel: NSTextField?
  
  
  @IBOutlet weak var paymentBox: NSBox?
  
  /** Payment fee label
   */
  @IBOutlet weak var paymentFeeLabel: NSTextField?
  
  /** Divider between payment request and payment request details
   */
  @IBOutlet weak var paymentHeadingDivider: NSBox?
  
  /** paymentHeadingTextField is the label for the payment invoice heading.
   */
  @IBOutlet weak var paymentHeadingTextField: NSTextField?
  
  /** Payment time label
   */
  @IBOutlet weak var paymentTimeLabel: NSTextField?
  
  /** Payment time text field
   */
  @IBOutlet weak var paymentTimeTextField: NSTextField?
  
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
  
  /** Send time fee
   */
  @IBOutlet weak var sendFeeTextField: NSTextField?

  /** Send to label
   */
  @IBOutlet weak var sendToLabel: NSTextField?
  
  /** Sent status
   */
  @IBOutlet weak var sentStatusTextField: NSTextField?
  
  // MARK: - Properties

  /** Payment request to send
   */
  fileprivate var paymentRequest: PaymentRequest? { didSet { updatedPaymentRequest() } }

  private func payment(on: Bool) {
    let shouldBeHidden = on == false
    
    let paymentElements: [NSView?] = [
      clearPaymentButton,
      paymentAmountLabel,
      paymentBox,
      paymentFeeLabel,
      paymentHeadingDivider,
      paymentHeadingTextField,
      paymentTimeLabel,
      paymentTimeTextField,
      sendAmountTextField,
      sendFeeTextField,
      sendToLabel,
      sendButton,
      sendToPublicKeyTextField,
    ]

    paymentElements.forEach { $0?.isHidden = shouldBeHidden }
  }
  
  fileprivate func updatedPaymentRequest() {
    guard let paymentRequest = paymentRequest else { return payment(on: false) }
    
    sendAmountTextField?.stringValue = "\(paymentRequest.tokens.formatted) tBTC"

    sendToPublicKeyTextField?.stringValue = paymentRequest.destination.hexEncoded
    
    sendButton?.stringValue = "Send Payment"
    sendButton?.state = NSOnState
    sendButton?.isEnabled = true
    
    payment(on: true)
  }

  var updateBalance: (() -> ())?

  // FIXME: - see if this can be done natively
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
        do { self?.paymentRequest = try PaymentRequest(from: data) } catch { print("ERROR", error) }
      }
    }
    
    task.resume()
  }
  
  private func sendCoins() {
    guard let sendAmount = paymentRequest?.tokens else { return }
    
    let session = URLSession.shared
    let sendUrl = URL(string: "http://localhost:10553/v0/payments/")!
    var sendUrlRequest = URLRequest(url: sendUrl, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 30)
    sendUrlRequest.httpMethod = "POST"
    sendUrlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let destination = (destinationTextField?.stringValue ?? String()) as String
    
    let data = "{\"payment_request\": \"\(destination)\"}".data(using: .utf8)
    
    sendButton?.isEnabled = false
    sendButton?.state = NSOffState
    sendButton?.title = "Sending..."

    let start = Date()
    
    // FIXME: - send over the socket
    let sendTask = session.uploadTask(with: sendUrlRequest, from: data) { [weak self] data, urlResponse, error in
      self?.sendButton?.isEnabled = true

      if let error = error {
        return print("ERROR \(error)")
      }
      
      DispatchQueue.main.async {
        self?.updateBalance?()
        
        self?.paymentRequest = nil
        
        self?.sendButton?.isEnabled = true
        self?.sendButton?.state = NSOnState
        self?.sendButton?.title = "Send Payment"
        
        self?.destinationTextField?.stringValue = String()
        
        let duration = Date().timeIntervalSince(start)
        
        self?.sentStatusTextField?.isHidden = false
        self?.sentStatusTextField?.stringValue = "Sent \(sendAmount.formatted) tBTC in \(String(format: "%.2f", duration)) seconds."
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
    sendButton?.title = "Send Payment"
    
    destinationTextField?.stringValue = String()
    paymentRequest = nil
    
    sentStatusTextField?.isHidden = true
    
    payment(on: false)
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    // Do view setup here.
    
    iconImageView?.wantsLayer = true
    iconImageView?.layer?.backgroundColor = NSColor.lightGray.cgColor
    iconImageView?.layer?.cornerRadius = 8
    iconImageView?.layer?.masksToBounds = true
    
    updatedPaymentRequest()
    
    sendToPublicKeyTextField?.formatter = OnlyValidPaymentRequestValueFormatter()
  }
  
  override func viewWillDisappear() {
    super.viewWillDisappear()
    
    sentStatusTextField?.isHidden = true
  }
}

// FIXME: - cleanup - localization prep
extension SendViewController: NSTextFieldDelegate {

  
  override func controlTextDidChange(_ obj: Notification) {
    paymentRequest = nil
    
    guard let destination = destinationTextField?.stringValue else { return }
    
    sentStatusTextField?.isHidden = true
    
    getDecoded(paymentRequest: destination)
  }
}
