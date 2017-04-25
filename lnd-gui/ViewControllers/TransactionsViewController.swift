//
//  TransactionsViewController.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 3/11/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Cocoa

// FIXME: - abstract
class TransactionsViewController: NSViewController {
  @IBOutlet weak var transactionsTableView: NSTableView?
  
  lazy var transactions: [Transaction] = [Transaction]()
}

// FIXME: - reload transactions when sending is complete
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
      
      let largeUnitValue: Double = Double(tx.tokens) / 100_000_000
      
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
      
      guard let createdAt = tx.createdAt else {
        title = " "
        
        break
      }
      
      title = "\(formatter.string(from: createdAt))"
      
    case .description:
      switch tx.destination {
      case .chain:
        title = " "
        
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

extension TransactionsViewController: WalletListener {
  func wallet(updated wallet: Wallet) {
    transactions = wallet.transactions
    
    transactionsTableView?.reloadData()
  }
}

