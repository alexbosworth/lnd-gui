//
//  TransactionsViewController.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 3/11/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Cocoa

/** Transactions view controller
 FIXME: - abstract
 */
class TransactionsViewController: NSViewController, ErrorReporting {
  // MARK: - @IBAction
  
  /** Double click on a transaction
   */
  @IBAction func doubleClickTransaction(_ sender: AnyObject) {
    guard let index = transactionsTableView?.clickedRow else { return }
    
    guard let transaction = transaction(at: index) else { return reportError(Failure.expectedTransactionForRow) }
    
    showTransaction(transaction)
  }
  
  // MARK: - @IBOutlets
  
  /** Transactions table view
   */
  @IBOutlet weak var transactionsTableView: NSTableView?
  
  // MARK: - Properties

  /** Report an error
   */
  lazy var reportError: (Error) -> () = { _ in }
  
  /** Show a transaction
   */
  lazy var showTransaction: (Transaction) -> () = { _ in }
  
  /** Transactions
   */
  lazy var transactions: [Transaction] = [Transaction]()
}

// MARK: - NSViewController
extension TransactionsViewController {
  /** View loaded
   */
  override func viewDidLoad() {
    super.viewDidLoad()
    
    initMenu()
  }
}

// MARK: - Columns
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

// MARK: - Failures
extension TransactionsViewController {
  /** Transaction view controller error
   */
  enum Failure: Error {
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

    let detailsLabel = NSLocalizedString("Details", comment: "Menu item to show transaction details")
    
    menu.addItem(NSMenuItem(title: detailsLabel, action: #selector(showTransactionDetails), keyEquivalent: String()))
  }
  
  /** Show transaction details
   */
  func showTransactionDetails(_ item: NSMenuItem) {
    guard let index = transactionsTableView?.clickedRow, let transaction = transaction(at: index) else { return }

    showTransaction(transaction)
  }
  
  /** Transaction at index
   */
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
    guard let col = Column(fromTableColumn: tableColumn) else { reportError(Failure.expectedKnownColumn); return nil }
    
    guard let tx = transaction(atRow: row) else { reportError(Failure.expectedTransactionForRow); return nil }

    let title: String
    
    switch col {
    case .amount:
      let modifier = tx.outgoing ? "-" : "+"
      
      title = "\(modifier)\(tx.tokens.formatted(with: .testBitcoin))"
      
    case .confirmed:
      let cell = col.makeCell(inTableView: tableView, withTitle: " ", isEnabled: tx.confirmed) as? TransactionStatusCell

      cell?.transaction = tx

      return cell
      
    case .createdAt:
      guard let createdAt = tx.createdAt else { title = " "; break }
      
      title = createdAt.formatted(dateStyle: .short, timeStyle: .short)
      
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
    
    return col.makeCell(inTableView: tableView, withTitle: title, isEnabled: tx.confirmed)
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
extension TransactionsViewController: NSTableViewDelegate {
  // FIXME: - reload transactions when sending is complete
  // FIXME: - need a menu so that for invoices I can get a payment request
}

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

