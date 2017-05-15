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
class ReceiveViewController: NSViewController {
  // MARK: - @IBActions

  /** pressedClearButton triggers clearing the current payment request.
   */
  @IBAction func pressedClearButton(_ button: NSButton) {
    clear()
  }
  
  /** Pressed blockchain item
   */
  @IBAction func pressedInvoiceBlockchainItem(_ item: NSMenuItem) {
    guard let chainAddress = invoice?.chainAddress else {
      return print("ERROR", "expected chain address")
    }
    
    paymentRequestTextField?.stringValue = chainAddress
  }

  /** Pressed lightning item
   */
  @IBAction func pressedInvoiceLightningItem(_ item: NSMenuItem) {
    guard let paymentRequest = invoice?.paymentRequest else {
      return print("ERROR", "expected payment request")
    }
    
    paymentRequestTextField?.stringValue = paymentRequest
  }
  
  /** pressedRequestButton triggers the creation of a new request
   */
  @IBAction func pressedRequestButton(_ button: NSButton) {
    guard let amountString = amountTextField?.stringValue else { return }
    
    let number = (NSDecimalNumber(string: amountString) as Decimal) * (NSDecimalNumber(value: 100_000_00) as Decimal)
    
    let amount = Tokens((number as NSDecimalNumber).doubleValue)
    
    do { try addInvoice(amount: amount, memo: memoTextField?.stringValue) } catch { print(error) }
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
  var invoice: Invoice? { didSet { updatePaymentRequest() } }

  /** Paid invoice
   */
  var paidInvoice: Transaction? { didSet { updatePaidInvoice() } }
  
  // MARK: - UIViewController
  
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

  /** Update paid invoice
   */
  private func updatePaidInvoice() {
    guard let paidInvoice = paidInvoice else { paymentReceivedBox?.isHidden = true; return }

    guard let invoiceDate = paidInvoice.createdAt else {
      return print("ERROR", "expected paid invoice date")
    }
    
    paymentReceivedBox?.isHidden = false
    
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    
    paymentInvoiceDate?.stringValue = formatter.string(from: invoiceDate)
    
    paymentReceivedAmount?.stringValue = "\(paidInvoice.tokens.formatted) tBTC"
    
    guard case .received(let invoice) = paidInvoice.destination else { return }
    
    paymentReceivedDescription?.stringValue = (invoice.memo ?? " ") as String
  }
  
  /** updatePaymentRequest updates the payment request label
   */
  private func updatePaymentRequest() {
    paymentRequestTextField?.stringValue = (invoice?.paymentRequest ?? String()) as String

    invoiceTypeButton?.isHidden = invoice?.paymentRequest == nil

    guard let invoice = invoice else { return }
    
    paymentRequestHeadingTextField?.isHidden = false
    paymentRequestTextField?.isHidden = false
    requestButton?.isEnabled = true
    requestButton?.state = NSOnState
    requestButton?.title = "Create Invoice"
  }
  
  /** viewDidLoad triggers to initialize the view.
   */
  override func viewDidLoad() {
    super.viewDidLoad()
    // Do view setup here.
    
    paymentReceivedBox?.isHidden = true
    
    clear()
  }
  
  /** View is going to disappear
   */
  override func viewWillDisappear() {
    super.viewWillDisappear()
    
    paidInvoice = nil
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

// MARK: - WalletListener
extension ReceiveViewController: WalletListener {
  /** Wallet was updated
   */
  func wallet(updated wallet: Wallet) {
    let hasSettledInvoice = wallet.transactions.contains { transaction in
      switch transaction.destination {
      case .chain, .sent(_, _):
        return false
        
      case .received(_) where transaction.id == invoice?.id && transaction.confirmed:
        paidInvoice = transaction
        
        return true

      case .received(_):
        return false
      }
    }
    
    guard hasSettledInvoice else { return }
    
    clear()
  }
}
