//
//  TransactionsViewController.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 3/11/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Cocoa

// FIXME: - include fee, hops and payment req
// FIXME: - reorganize
struct Transaction {
  let amount: UInt64
  let confirmed: Bool
  let destination: DestinationType
  let createdAt: Date
  let outgoing: Bool

  enum DestinationType {
    case received(memo: String)
    case sent(publicKey: String, paymentId: String)
  }
  
  enum JsonParseError: String, Error {
    case expectedAmount
    case expectedConfirmedFlag
    case expectedCreatedAtDate
    case expectedMemo
    case expectedOutgoingFlag
    case expectedSentDestination
  }
  
  init(from json: [String: Any]) throws {
    guard let amount = (json["amount"] as? NSNumber)?.uint64Value else { throw JsonParseError.expectedAmount }
    
    guard let confirmed = (json["confirmed"] as? Bool) else { throw JsonParseError.expectedConfirmedFlag }
    
    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"

    guard
      let createdAtString = (json["created_at"] as? String),
      let createdAt = dateFormatter.date(from: createdAtString) else { throw JsonParseError.expectedCreatedAtDate }
    
    guard let outgoing = (json["outgoing"] as? Bool) else { throw JsonParseError.expectedOutgoingFlag }
    
    self.amount = amount
    self.confirmed = confirmed
    self.createdAt = createdAt
    self.outgoing = outgoing

    switch outgoing {
    case false:
      guard let memo = json["memo"] as? String else { throw JsonParseError.expectedMemo }
      
      destination = DestinationType.received(memo: memo)
      
    case true:
      guard let publicKey = json["destination"] as? String, let paymentId = json["id"] as? String else {
        throw JsonParseError.expectedSentDestination
      }
      
      destination = DestinationType.sent(publicKey: publicKey, paymentId: paymentId)
    }
  }
}

// FIXME: - abstract
class TransactionsViewController: NSViewController {
  @IBOutlet weak var transactionsTableView: NSTableView?
  
  lazy var transactions: [Transaction] = [Transaction]()
  
  override func viewDidLoad() {
    super.viewDidLoad()
  }
  
  override func viewDidAppear() {
    super.viewDidAppear()
    
    refreshHistory()
  }
}

extension TransactionsViewController {
  func refreshHistory() {
    let url = URL(string: "http://localhost:10553/v0/history/")!
    let session = URLSession.shared
    
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    
    let task = session.dataTask(with: request) { [weak self] data, urlResponse, error in
      guard let historyData = data else { return print("Expected history data") }
      
      let dataDownloadedAsJson = try? JSONSerialization.jsonObject(with: historyData, options: .allowFragments)
      
      guard let history = dataDownloadedAsJson as? [[String: Any]] else {
        return print("Expected history json")
      }

      do {
        let transactions = try history.map { try Transaction(from: $0) }
        
        DispatchQueue.main.async {
          self?.transactions = transactions
          
          self?.transactionsTableView?.reloadData()
        }
      } catch {
        print("Failed to parse transaction history \(error)")
      }
    }
    
    task.resume()
  }
}

extension TransactionsViewController {
  /** Table columns
   */
  fileprivate enum Column: String {
    case amount = "AmountColumn"
    case confirmed = "ConfirmedColumn"
    case createdAt = "CreatedAtColumn"
    case description = "DescriptionColumn"
    
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
      case .amount:
        return "AmountCell"
        
      case .confirmed:
        return "ConfirmedCell"
        
      case .createdAt:
        return "CreatedAtCell"
        
      case .description:
        return "DescriptionCell"
      }
    }
    
    /** Column identifier
     */
    var asColumnIdentifier: String { return rawValue }
    
    /** Make a cell in column
     */
    func makeCell(inTableView tableView: NSTableView, withTitle title: String) -> NSTableCellView? {
      let cell = tableView.make(withIdentifier: asCellIdentifier, owner: nil) as? NSTableCellView
      
      cell?.textField?.stringValue = title
      
      return cell
    }
  }
}

extension TransactionsViewController {
  enum TransactionsViewControllerError: String, Error {
    case expectedKnownColumn
    case expectedTransactionForRow
  }
}

// FIXME: - animate changes
extension TransactionsViewController: NSTableViewDataSource {
  func numberOfRows(in tableView: NSTableView) -> Int {
    return transactions.count
  }
  
  /** Make cell for row at column
   */
  func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
    guard let column = Column(fromTableColumn: tableColumn) else {
      print(TransactionsViewControllerError.expectedKnownColumn)
      
      return nil
    }
    
    guard let tx = transaction(atRow: row) else {
      print(TransactionsViewControllerError.expectedTransactionForRow)
      
      return nil
    }

    let title: String
    
    switch column {
    case .amount:
      let modifier = tx.outgoing ? "-" : "+"
      
      let largeUnitValue: Double = Double(tx.amount) / 100_000_000
      
      let formatter = NumberFormatter()
      
      formatter.minimumFractionDigits = 8
      formatter.minimumIntegerDigits = 1
      
      let formattedAmount = formatter.string(from: NSNumber(value: largeUnitValue)) ?? String()
      
      title = "\(modifier)\(formattedAmount) tBTC"
      
    case .confirmed:
      title = tx.confirmed ? "✅" : "❔"
      
    case .createdAt:
      let formatter = DateFormatter()
      formatter.dateStyle = .short
      formatter.timeStyle = .short
      
      title = "\(formatter.string(from: tx.createdAt))"
      
    case .description:
      switch tx.destination {
      case .received(memo: let memo):
        title = memo
        
      case .sent(publicKey: let publicKey, paymentId: let paymentId):
        title = "Sent to \(publicKey) for \(paymentId)"
      }
    }
    
    return column.makeCell(inTableView: tableView, withTitle: title)
  }
  
  func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
    return nil
  }
  
  /** Get a transaction for a row #
   */
  fileprivate func transaction(atRow row: Int) -> Transaction? {
    guard row >= Int() && row < transactions.count else { return nil }
    
    return transactions[row]
  }

}

extension TransactionsViewController: NSTableViewDelegate {
  
}
