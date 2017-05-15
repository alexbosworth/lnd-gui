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
  // MARK: - @IBAction
  
  @IBAction func doubleClickTransaction(_ sender: AnyObject) {
    guard let index = transactionsTableView?.clickedRow else { return }
    
    guard let transaction = transaction(at: index) else {
      return print("ERROR", "expected transaction at index")
    }
    
    showTransaction(transaction)
  }
  
  // MARK: - @IBOutlets
  
  @IBOutlet weak var transactionsTableView: NSTableView?
  
  // MARK: - Properties

  lazy var showTransaction: (Transaction) -> () = { _ in }
  
  lazy var transactions: [Transaction] = [Transaction]()
}

// MARK: - NSViewController
extension TransactionsViewController {
  override func viewDidLoad() {
    super.viewDidLoad()
    
    initMenu()
  }
}

// FIXME: - reload transactions when sending is complete
// FIXME: - need a menu so that for invoices I can get a payment request
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
    func makeCell(inTableView tableView: NSTableView, withTitle title: String, isEnabled: Bool) -> NSTableCellView? {
      let cell = tableView.make(withIdentifier: asCellIdentifier, owner: nil) as? NSTableCellView
      
      cell?.textField?.stringValue = title
      
      cell?.textField?.textColor = isEnabled ? .controlTextColor : .disabledControlTextColor
      
      return cell
    }
  }
}

// MARK: - Errors
extension TransactionsViewController {
  /** Transaction view controller error
   */
  enum TransactionsViewControllerError: String, Error {
    case expectedKnownColumn
    case expectedTransactionForRow
  }
}

// MARK: - NSMenuDelegate
extension TransactionsViewController: NSMenuDelegate {
  /** Init the table menu
   */
  fileprivate func initMenu() {
    transactionsTableView?.menu = NSMenu()
    
    transactionsTableView?.menu?.delegate = self
  }
  
  /** Context menu is appearing
   */
  func menuNeedsUpdate(_ menu: NSMenu) {
    menu.removeAllItems()
    
    guard let index = transactionsTableView?.clickedRow, let _ = transaction(at: index) else { return }

    menu.addItem(NSMenuItem(title: "Details", action: #selector(showTransactionDetails), keyEquivalent: String()))
  }
  
  func showTransactionDetails(_ item: NSMenuItem) {
    guard let index = transactionsTableView?.clickedRow, let transaction = transaction(at: index) else { return }

    showTransaction(transaction)
  }
  
  func transaction(at index: Int) -> Transaction? {
    guard !transactions.isEmpty, index >= transactions.startIndex, index < transactions.endIndex else { return nil }

    return transactions[index]
  }
}

// MARK: - NSTableViewDataSource
extension TransactionsViewController: NSTableViewDataSource {
  /** Number of rows in table
   */
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
      let cell = column.makeCell(inTableView: tableView, withTitle: " ", isEnabled: tx.confirmed) as? TransactionStatusCell

      cell?.transaction = tx

      return cell
      
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
        title = tx.id
        
      case .received(let invoice):
        title = invoice.memo ?? invoice.id
        
      case .sent(publicKey: let publicKey, paymentId: let paymentId):
        title = "Sent to \(publicKey) for \(paymentId)"
      }
    }
    
    return column.makeCell(inTableView: tableView, withTitle: title, isEnabled: tx.confirmed)
  }
  
  /** Object value at row
   */
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

// MARK: - NSTableViewDelegate
extension TransactionsViewController: NSTableViewDelegate {}

// MARK: - WalletListener
extension TransactionsViewController: WalletListener {
  /** Wallet updated
   */
  func wallet(updated wallet: Wallet) {
    transactions = (wallet.transactions + wallet.unconfirmedTransactions).uniqueElements

    transactions.sort() { ($0.createdAt ?? Date()) as Date > ($1.createdAt ?? Date()) as Date }

    // FIXME: - animate changes
    
    transactionsTableView?.reloadData()
  }
}

