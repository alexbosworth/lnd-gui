//
//  ReceiveViewController.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 3/12/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Cocoa

// FIXME: - clean up
struct Invoice {
  let id: String // rhash
  let paymentRequest: String
  
  enum JsonParseError: String, Error {
    case expectedId
    case expectedPaymentRequest
  }
  
  init(from json: [String: Any]) throws {
    guard let id = json["id"] as? String else { throw JsonParseError.expectedId }
    
    guard let paymentRequest = json["payment_request"] as? String else { throw JsonParseError.expectedPaymentRequest }
    
    self.id = id
    self.paymentRequest = paymentRequest
  }
}

// FIXME: - cleanup
class ReceiveViewController: NSViewController {
  @IBAction func pressedClearButton(_ button: NSButton) {
    amountTextField?.stringValue = String()
    memoTextField?.stringValue = String()
    paymentRequestHeadingTextField?.isHidden = true
    paymentRequestTextField?.isHidden = true
  }
  
  @IBAction func pressedRequestButton(_ button: NSButton) {
    guard let amountString = amountTextField?.stringValue, let amount = Float(amountString) else { return }
    
    do { try addInvoice(amount: amount, memo: memoTextField?.stringValue) } catch { print(error) }
  }
  
  @IBOutlet weak var amountTextField: NSTextField?

  @IBOutlet weak var memoTextField: NSTextField?
  
  @IBOutlet weak var paymentRequestHeadingTextField: NSTextField?
  
  @IBOutlet weak var paymentRequestTextField: NSTextField?
  
  @IBOutlet weak var requestButton: NSButton?
  
  var invoice: Invoice? {
    didSet {
      paymentRequestTextField?.stringValue = invoice?.paymentRequest ?? String()
    }
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    // Do view setup here.
    
    paymentRequestTextField?.isHidden = true
    paymentRequestHeadingTextField?.isHidden = true
  }
}

extension ReceiveViewController {
  func addInvoice(amount: Float, memo: String? = nil) throws {
    let session = URLSession.shared
    let sendUrl = URL(string: "http://localhost:10553/v0/invoices/")!
    var sendUrlRequest = URLRequest(url: sendUrl, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 30)
    sendUrlRequest.httpMethod = "POST"
    sendUrlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let amount = Int(amount * 100_000_000)
    let memo = memo ?? String()
    
    let json: [String: Any] = ["amount": amount, "memo": memo]
    
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
        return print(error)
      }
      
      DispatchQueue.main.async {
        self?.invoice = invoice
        self?.paymentRequestHeadingTextField?.isHidden = false
        self?.paymentRequestTextField?.isHidden = false
        self?.requestButton?.isEnabled = true
        self?.requestButton?.state = NSOnState
        self?.requestButton?.title = "Create Invoice"
      }
    }
    
    task.resume()
  }
}
