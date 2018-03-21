//
//  BlockchainInfoViewController.swift
//  lnd-gui
//
//  Created by Alexander Bosworth on 3/25/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Cocoa

// FIXME: - add a way to get notified on a transaction when it confirms
// FIXME: - eliminate all this fake stuff

enum TransactionLookupResult {
  case error(Error)
  case transaction(BlockchainTransaction)
}

enum TransactionLookupError: String, Error {
  case expectedBlockchainTransaction
}

class BlockchainInfoViewController: NSViewController {
  @IBAction func search(_ sender: NSSearchField) {
    updateSearch(query: sender.stringValue)
  }
  
  @IBOutlet weak var purchaseProgressIndicator: NSProgressIndicator?
  
  @IBOutlet weak var querySearchField: NSSearchField?
  
  @IBOutlet weak var queryPriceTextField: NSTextField?

  @IBOutlet weak var transactionIdTextField: NSTextField?
  
  @IBOutlet weak var transactionTitleTextField: NSTextField?
  
  @IBOutlet weak var transactionInputsScrollView: NSScrollView?
  
  @IBOutlet weak var transactionInputsTableView: NSTableView?
  
  @IBOutlet weak var transactionOutputsScrollView: NSScrollView?
  
  @IBOutlet weak var transactionOutputsTableView: NSTableView?
  
  @IBOutlet weak var transactionConfirmationCountTextField: NSTextField?
  
  @IBOutlet weak var transactionConfirmationProgressIndicator: NSProgressIndicator?
  
  @IBOutlet weak var transactionOutputSumTextField: NSTextField?
  
  enum TransactionInfoResult {
    case transaction(BlockchainTransaction)
    case error(Error)
  }
  
  enum GetTransactionInfoFailure: Error {
    case expectedData
    case expectedJson
    case expectedJsonObject
    case unexpectedStatusCode
  }
  
  enum HttpStatus: Int {
    case ok = 200
    
    var code: Int { return rawValue }
  }
  
  func pay(invoice: SerializedInvoice, completion: @escaping (Error?) -> ()) {
    let session = URLSession.shared
    let sendUrl = URL(string: "http://localhost:10553/v0/payments/")!
    var sendUrlRequest = URLRequest(url: sendUrl, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 30)
    sendUrlRequest.httpMethod = "POST"
    sendUrlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let data = "{\"invoice\": \"\(invoice)\"}".data(using: .utf8)
    
    let sendTask = session.uploadTask(with: sendUrlRequest, from: data) { data, urlResponse, error in
      if let error = error {
        return completion(error)
      }
      
      completion(nil)
    }
    
    sendTask.resume()
  }
  
  func get(transaction id: String, completion: @escaping (TransactionInfoResult) -> ()) {
    let url = URL(string: "http://localhost:10553/v0/blockchain/transaction_info/\(id)")!
    let session = URLSession.shared
    
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    
    let task = session.dataTask(with: request) { data, urlResponse, error in
      if let error = error { return completion(.error(error)) }
      
      guard (urlResponse as? HTTPURLResponse)?.statusCode == HttpStatus.ok.code else {
        return completion(.error(GetTransactionInfoFailure.unexpectedStatusCode))
      }
      
      guard let data = data else { return completion(.error(GetTransactionInfoFailure.expectedData)) }
      
      guard let jsonObject = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) else {
        return completion(.error(GetTransactionInfoFailure.expectedJsonObject))
      }
      
      guard let json = jsonObject as? [String: Any] else {
        return completion(.error(GetTransactionInfoFailure.expectedJson))
      }
      
      do {
        return completion(.transaction(try BlockchainTransaction(from: json)))
      } catch {
        return completion(.error(error))
      }
    }
    
    task.resume()
  }
  
  func lookupTransaction(id: String, completion: @escaping (TransactionLookupResult) -> ()) {
    let queue = TaskQueue()
    
    let hasError: (Error) -> () = { [weak queue] error in queue?.cancel(); return completion(.error(error)) }

    purchaseProgressIndicator?.doubleValue = 0
    purchaseProgressIndicator?.isHidden = false
    purchaseProgressIndicator?.isIndeterminate = false
    
    // Get invoice from remote service for tx info
    queue.tasks += { [weak self] _, completion in
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        self?.purchaseProgressIndicator?.increment(by: 33)
        
        completion(nil)
      }
    }
    
    // Send payment to payment request
    queue.tasks += { [weak self] _, completion in
      let payReq = "ypn496i5mq1qszjykswo9d88na575nyncyq3gtm3pe11qfuje7ttpb3zpo77c6rjer1owsi1xxt1umip9em1faqzx1869guitab5pm78yyyyyyyyyyeqdx5szwky"

      self?.pay(invoice: payReq) { error in
        if let error = error { return hasError(error) }

        DispatchQueue.main.async { self?.purchaseProgressIndicator?.increment(by: 33) }
        
        completion(nil)
      }
    }
    
    // Use payment request receipt to get tx info
    queue.tasks += { [weak self] _, completion in
      DispatchQueue.main.async {
        self?.get(transaction: id) { result in
          switch result {
          case .error(let error):
            hasError(error)
            
          case .transaction(let transaction):
            completion(transaction)
          }
        }
      }
    }
    
    queue.run() {
      guard let tx = queue.lastResult as? BlockchainTransaction else {
        return completion(.error(TransactionLookupError.expectedBlockchainTransaction))
      }
      
      return completion(.transaction(tx))
    }
  }

  var transaction: BlockchainTransaction? {
    didSet {
      updateTransactionDetails()
    }
  }
  
  private func updateTransactionDetails() {
    enum SearchResult {
      case none
      case transaction(BlockchainTransaction)
    }

    let searchResult: SearchResult
    
    if let tx = transaction { searchResult = .transaction(tx) } else { searchResult = .none }

    let transactionDetailViews: [NSView?] = [
      transactionIdTextField,
      transactionInputsScrollView,
      transactionTitleTextField,
      transactionConfirmationCountTextField,
      transactionConfirmationProgressIndicator,
      transactionOutputSumTextField,
      transactionOutputsScrollView,
      purchaseProgressIndicator
    ]
    
    switch searchResult {
    case .none:
      transactionDetailViews.forEach { $0?.isHidden = true }
      
      purchaseProgressIndicator?.doubleValue = Double()
      
    case .transaction(let transaction):
      transactionDetailViews.forEach { $0?.isHidden = false }
      
      let confidentConfirmations = 6

      guard let outputs = transaction.outputs else { break }
      
      let sentValue = outputs.reduce(Tokens()) { $0 + $1.tokens }
      
      transactionIdTextField?.stringValue = transaction.id
      transactionConfirmationProgressIndicator?.doubleValue = Double(100) * (Double(transaction.confirmationCount) / Double(confidentConfirmations))
      transactionConfirmationCountTextField?.stringValue = "\(transaction.confirmationCount) Confirmations"
      transactionOutputSumTextField?.stringValue = "\(sentValue.formatted) tBTC"
      
      purchaseProgressIndicator?.isHidden = true
    }

    [transactionInputsTableView, transactionOutputsTableView].forEach { $0?.reloadData() }
  }
  
  func updateSearch(query: String) {
    queryPriceTextField?.isHidden = query.isEmpty

    guard !query.isEmpty else { return transaction = nil }
    
    guard query != transaction?.id else { return }
    
    lookupTransaction(id: query) { [weak self] result in
      let tx: BlockchainTransaction?
      
      switch result {
      case .error(let error):
        print(error)
        
        tx = nil
        
      case .transaction(let transaction):
        tx = transaction
      }
      
      DispatchQueue.main.async { self?.transaction = tx }
    }
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    // Do view setup here.
  }
  
}

extension BlockchainInfoViewController: NSTableViewDataSource {
  func numberOfRows(in tableView: NSTableView) -> Int {
    guard let inputsTable = transactionInputsTableView, let outputsTable = transactionOutputsTableView else {
      print("Expected table views")
      
      return Int()
    }
    
    switch tableView {
    case inputsTable:
      return (transaction?.inputs?.count ?? Int()) as Int
      
    case outputsTable:
      return (transaction?.outputs?.count ?? Int()) as Int
      
    default:
      print("Unexpected table")
      
      return Int()
    }
  }

  /** Table columns
   */
  fileprivate enum Column: String {
    case inputTransactionId = "InputTransactionIdColumn"
    case outputAddress = "OutputAddressColumn"
    case outputValue = "OutputValueColumn"
    
    /** Create from a table column
     */
    init?(fromTableColumn: NSTableColumn?) {
      guard let id = fromTableColumn?.identifier, let column = type(of: self).init(rawValue: id) else {
        return nil
      }
      
      self = column
    }
    
    /** Cell identifier for column cell
     */
    var asCellIdentifier: String {
      switch self {
      case .inputTransactionId:
        return "InputTransactionIdCell"
        
      case .outputAddress:
        return "OutputAddressCell"
        
      case .outputValue:
        return "OutputValueCell"
      }
    }
    
    /** Column identifier
     */
    var asColumnIdentifier: String { return rawValue }
    
    /** Make a cell in column
     */
    func makeCell(inTableView tableView: NSTableView, withTitle title: String) -> NSTableCellView? {
      let cell = tableView.make(withIdentifier: asCellIdentifier, owner: nil) as? NSTableCellView
      
      let title = title.isEmpty ? " " : title
      
      cell?.textField?.stringValue = title
      
      return cell
    }
  }
  
  func input(at row: Int) -> BlockchainTransactionInput? {
    guard let inputs = transaction?.inputs, !inputs.isEmpty else { return nil }
    
    guard row >= inputs.startIndex && row < inputs.endIndex else { return nil }
    
    return inputs[row]
  }
  
  func output(at row: Int) -> BlockchainTransactionOutput? {
    guard let outputs = transaction?.outputs, !outputs.isEmpty else { return nil }
    
    guard row >= outputs.startIndex && row < outputs.endIndex else { return nil }
    
    return outputs[row]
  }
  
  /** Make cell for row at column
   */
  func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
    guard let inputsTable = transactionInputsTableView, let outputsTable = transactionOutputsTableView else {
      print("Expected table views"); return nil
    }

    guard let column = Column(fromTableColumn: tableColumn) else {
      print("expected known column")
      
      return nil
    }
    
    let title: String
    
    switch tableView {
    case inputsTable:
      guard let input = input(at: row) else {
        print("expected input at row")
        
        title = String()
        
        break
      }
      
      switch column {
      case .inputTransactionId:
        title = "\(input.transactionId):\(input.vout)"
        
      case .outputAddress, .outputValue:
        print("expected input column")
        
        title = String()
      }
      
    case outputsTable:
      guard let output = output(at: row) else {
        print("expected output at row")
        
        title = String()
        
        break
      }
      
      switch column {
      case .inputTransactionId:
        print("Expected output column")
        
        title = String()
        
      case .outputAddress:
        title = output.address
        
      case .outputValue:
        title = "\(output.tokens.formatted) tBTC"
      }

    default:
      print("Unexpected table")

      title = String()
    }
    
    return column.makeCell(inTableView: tableView, withTitle: title)
  }
}

extension BlockchainInfoViewController: NSTableViewDelegate {}

extension BlockchainInfoViewController: NSSearchFieldDelegate {
  func searchFieldDidEndSearching(_ sender: NSSearchField) {
    updateSearch(query: sender.stringValue)
  }
}


