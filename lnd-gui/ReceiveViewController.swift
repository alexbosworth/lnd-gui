//
//  ReceiveViewController.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 3/12/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Cocoa

/** ReceiveViewController is a view controller for creating invoices
 
 FIXME: - disable the clear button when there is nothing to clear
 FIXME: - disable the create invoice button when there is nothing to create
 FIXME: - add copy button
 FIXME: - don't allow entering too much or too little Satoshis
 FIXME: - when received, show received notification
 FIXME: - add fiat
 FIXME: - add receive on chain bitcoins method
 */
class ReceiveViewController: NSViewController, ErrorReporting {
  // MARK: - @IBActions

  /** Pressed clear button triggers clearing the current payment request.
   */
  @IBAction func pressedClearButton(_ button: NSButton) {
    clear()
  }
  
  /** Pressed blockchain item
   */
  @IBAction func pressedInvoiceBlockchainItem(_ item: NSMenuItem) {
    guard let chainAddress = invoice?.chainAddress else { return reportError(Failure.expectedChainAddress) }
    
    paymentRequestTextField?.stringValue = chainAddress
  }

  /** Pressed lightning item
   */
  @IBAction func pressedInvoiceLightningItem(_ item: NSMenuItem) {
    guard let paymentRequest = invoice?.paymentRequest else { return reportError(Failure.expectedPaymentRequest) }
    
    paymentRequestTextField?.stringValue = paymentRequest
  }
  
  /** Pressed request button to trigger the creation of a new request
   */
  @IBAction func pressedRequestButton(_ button: NSButton) {
    guard let amountString = amountTextField?.stringValue else { return }

    do { try addInvoice(amount: Tokens(from: amountString), memo: memoTextField?.stringValue) } catch { print(error) }
  }

  // MARK: - @IBOutlets

  /** amountTextField is the input text field for the invoice amount.
   */
  @IBOutlet weak var amountTextField: NSTextField?
  
  /** Switcher for invoice type
   */
  @IBOutlet weak var invoiceTypeButton: NSPopUpButton?

  /** memoTextField is the input text field for the memo.
   */
  @IBOutlet weak var memoTextField: NSTextField?
  
  /** Invoice date text field
   */
  @IBOutlet weak var paymentInvoiceDate: NSTextField?

  /** Payment received amount
   */
  @IBOutlet weak var paymentReceivedAmount: NSTextField?

  /** Payment received box
   */
  @IBOutlet weak var paymentReceivedBox: NSBox?

  /** Payment received description
   */
  @IBOutlet weak var paymentReceivedDescription: NSTextField?
  
  /** paymentRequestHeadingTextField is the label showing the payment request header.
   */
  @IBOutlet weak var paymentRequestHeadingTextField: NSTextField?
  
  /** paymentRequestTextField is the label showing the full payment request.
   */
  @IBOutlet weak var paymentRequestTextField: NSTextField?
  
  /** requestButton is the button that triggers the creation of a new payment request
   */
  @IBOutlet weak var requestButton: NSButton?
  
  /** Select lightning invoice item
   */
  @IBOutlet weak var selectLightningItem: NSMenuItem?
  
  // MARK: - Properties
  
  /** invoice is the created invoice to receive funds to.
   */
  var invoice: Invoice? { didSet { updatedPaymentRequest() } }

  /** Paid invoice
   */
  var paidInvoice: Transaction? { didSet { updatedPaidInvoice() } }
  
  /** Report error
   */
  lazy var reportError: (Error) -> () = { _ in }
}

// MARK: - Failures
extension ReceiveViewController {
  enum Failure: Error {
    case expectedChainAddress
    case expectedInvoiceCreationDate
    case expectedPaymentRequest
  }
}

// MARK: - Networking
extension ReceiveViewController {
  /** addInvoice sends a request to make an invoice.
   */
  func addInvoice(amount: Tokens, memo: String? = nil) throws {
    let session = URLSession.shared
    let sendUrl = URL(string: "http://localhost:10553/v0/invoices/")!
    var sendUrlRequest = URLRequest(url: sendUrl, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 30)
    sendUrlRequest.httpMethod = "POST"
    sendUrlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let memo = (memo ?? String()) as String
    
    let json: [String: Any] = ["include_address": true, "memo": memo, "tokens": amount]
    
    let data = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
    
    requestButton?.isEnabled = false
    requestButton?.state = NSOffState
    requestButton?.title = "Creating Invoice"
    
    let task = session.uploadTask(with: sendUrlRequest, from: data) { [weak self] data, urlResponse, error in
      if let error = error {
        return print("Create invoice error \(error)")
      }
      
      guard let data = data else {
        return print("Expected data")
      }
      
      let invoice: Invoice
      
      do {
        guard let json = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] else {
          return print("EXPECTED JSON")
        }
        
        invoice = try Invoice(from: json)
      } catch {
        return print("PARSE INVOICE ERROR", error)
      }

      // FIXME: - on error, reset the form, show error
      DispatchQueue.main.async {
        self?.invoice = invoice
      }
    }
    
    task.resume()
  }
}

// MARK: - NSViewController
extension ReceiveViewController {
  /** clear eliminates the input and previous created invoice from the view.
   */
  fileprivate func clear() {
    let addedInvoiceViews: [NSView?] = [paymentRequestHeadingTextField, paymentRequestTextField, invoiceTypeButton]
    let inputTextFields = [amountTextField, memoTextField]
    
    inputTextFields.forEach { $0?.stringValue = String() }
    addedInvoiceViews.forEach { $0?.isHidden = true }
    
    invoiceTypeButton?.select(selectLightningItem)
    
    paidInvoice = nil
  }
  
  /** Updated paid invoice
   */
  fileprivate func updatedPaidInvoice() {
    guard let paidInvoice = paidInvoice else { paymentReceivedBox?.isHidden = true; return }
    
    guard let invoiceDate = paidInvoice.createdAt else { return reportError(Failure.expectedInvoiceCreationDate) }
    
    paymentInvoiceDate?.stringValue = invoiceDate.formatted(dateStyle: .short, timeStyle: .short)
    paymentReceivedAmount?.stringValue = paidInvoice.tokens.formatted(with: .testBitcoin)
    paymentReceivedBox?.isHidden = false
    
    guard case .received(let invoice) = paidInvoice.destination else { return }
    
    paymentReceivedDescription?.stringValue = (invoice.memo ?? String()) as String
  }
  
  /** Updated the payment request
   */
  fileprivate func updatedPaymentRequest() {
    paymentRequestTextField?.stringValue = (invoice?.paymentRequest ?? String()) as String
    
    let hasNoPaymentRequest = invoice?.paymentRequest == nil
    
    invoiceTypeButton?.isHidden = hasNoPaymentRequest
    
    guard let _ = invoice else { return }
    
    paymentRequestHeadingTextField?.isHidden = false
    paymentRequestTextField?.isHidden = false
    requestButton?.isEnabled = true
    requestButton?.state = NSOnState
    requestButton?.title = NSLocalizedString("Create Invoice", comment: "Button to add a new payment request")
  }
  
  /** viewDidLoad triggers to initialize the view.
   */
  override func viewDidLoad() {
    super.viewDidLoad()
    
    clear()
  }
  
  /** View is going to disappear
   */
  override func viewWillDisappear() {
    super.viewWillDisappear()
    
    paidInvoice = nil
  }
}

// MARK: - WalletListener
extension ReceiveViewController: WalletListener {
  /** Wallet was updated
   */
  func wallet(updated wallet: Wallet) {
    guard let invoice = invoice, let currentInvoice = wallet.invoice(invoice), currentInvoice.confirmed else { return }

    paidInvoice = currentInvoice
    
    clear()
  }
}
