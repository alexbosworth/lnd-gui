//
//  MainTabViewController.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 3/5/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Cocoa

/** Main Tab View Controller
 */
class MainTabViewController: NSTabViewController {
  // MARK: - Properties
  
  /** Connections view controller
   */
  var connectionsViewController: ConnectionsViewController?

  /** Receive view controller
   */
  var receiveViewController: ReceiveViewController?
  
  /** Report errors
   */
  lazy var reportError: (Error) -> () = { _ in }
  
  /** Send view controller
   */
  var sendViewController: SendViewController?
  
  /** Show invoice
   */
  lazy var showInvoice: (LightningInvoice) -> () = { _ in }
  
  /** Show payment
   */
  lazy var showPayment: (LightningPayment) -> () = { _ in }
  
  /** Transactions view controller
   */
  var transactionsViewController: TransactionsViewController?
  
  /** Wallet
   */
  var wallet: Wallet?
}

// MARK: - ErrorReporting
extension MainTabViewController: ErrorReporting {
  /** Failure defines an encountered error.
   */
  enum Failure: Error {
    case expectedTab(Tab)
    case expectedViewControllerForTab(Tab)
    case expectedWalletForTabs
  }
}

// MARK: - Navigation
extension MainTabViewController {
  /** Tab defines a tab in the tab view controller.
   */
  enum Tab {
    case connections
    case receive
    case send
    case transactions

    /** storyboardIdentifier returns the identifier used in the storyboard for the tab.
     */
    var storyboardIdentifier: StoryboardIdentifier {
      switch self {
      case .connections:
        return "ConnectionsTab"
        
      case .receive:
        return "ReceiveTab"
        
      case .send:
        return "SendTab"
        
      case .transactions:
        return "TransactionsTab"
      }
    }
  }
  
  /** Show a payment to confirm
   */
  func showPayment(_ invoice: SerializedInvoice) throws {
    guard let sendViewController = sendViewController else { throw Failure.expectedViewControllerForTab(.send) }

    let sendTabIndex = tabView.indexOfTabViewItem(withIdentifier: Tab.send.storyboardIdentifier)

    selectedTabViewItemIndex = sendTabIndex
    
    sendViewController.destinationTextField?.stringValue = invoice
    sendViewController.didChangeDestination()
    sendViewController.wallet = wallet
  }
  
  /** Show connections
   
   // FIXME: - Connections should be shown in a preferences window
   */
  func showConnections() {
    guard let connections = connectionsViewController else {
      return reportError(Failure.expectedViewControllerForTab(.connections))
    }
    
    let connectionsTabIndex = tabView.indexOfTabViewItem(withIdentifier: Tab.connections.storyboardIdentifier)
    
    guard connectionsTabIndex == NSNotFound else { return selectedTabViewItemIndex = connectionsTabIndex }
    
    let insertionIndex = tabViewItems.endIndex

    // Add connections view controller
    insertChildViewController(connections, at: insertionIndex)
    
    // Show tab
    selectedTabViewItemIndex = insertionIndex
  }

  /** Show transaction
   */
  func showTransaction(_ transaction: Transaction) {
    switch transaction {
    case .blockchain(_):
      break
      
    case .lightning(let transaction):
      switch transaction {
      case .invoice(let invoice):
        return showInvoice(invoice)
        
      case .payment(let payment):
        return showPayment(payment)
      }
    }
  }
}

// MARK: - NSViewController
extension MainTabViewController {
  /** View did load
   */
  override func viewDidLoad() {
    super.viewDidLoad()
    
    let connectionsTabIndex = tabView.indexOfTabViewItem(withIdentifier: Tab.connections.storyboardIdentifier)

    if connectionsTabIndex >= tabViewItems.startIndex && connectionsTabIndex < tabViewItems.endIndex {
      connectionsViewController = childViewControllers[connectionsTabIndex] as? ConnectionsViewController
      
      connectionsViewController?.reportError = { [weak self] error in self?.reportError(error) }
      
      removeChildViewController(at: connectionsTabIndex)
    }
    
    let receiveTabIndex = tabView.indexOfTabViewItem(withIdentifier: Tab.receive.storyboardIdentifier)
    
    guard receiveTabIndex < tabViewItems.endIndex && receiveTabIndex >= tabViewItems.startIndex else {
      return reportError(Failure.expectedTab(.receive))
    }
    
    let receiveTab = tabViewItems[receiveTabIndex]
    
    guard let receiveViewController = receiveTab.viewController as? ReceiveViewController else {
      return reportError(Failure.expectedViewControllerForTab(.receive))
    }
    
    self.receiveViewController = receiveViewController

    receiveViewController.reportError = { [weak self] error in self?.reportError(error) }
    receiveViewController.showInvoice = { [weak self] invoice in self?.showInvoice(invoice) }
    
    let sendTabIndex = tabView.indexOfTabViewItem(withIdentifier: Tab.send.storyboardIdentifier)
    
    guard sendTabIndex < tabViewItems.endIndex && sendTabIndex >= tabViewItems.startIndex else {
      return reportError(Failure.expectedTab(.send))
    }
    
    let sendTab = tabViewItems[sendTabIndex]
    
    guard let sendViewController = sendTab.viewController as? SendViewController else {
      return reportError(Failure.expectedViewControllerForTab(.send))
    }
    
    self.sendViewController = sendViewController
    
    sendViewController.reportError = { [weak self] in self?.reportError($0) }
    sendViewController.wallet = wallet

    let transactionsTabIndex = tabView.indexOfTabViewItem(withIdentifier: Tab.transactions.storyboardIdentifier)
    
    guard transactionsTabIndex < tabViewItems.endIndex, transactionsTabIndex >= tabViewItems.startIndex else {
      return reportError(Failure.expectedTab(.transactions))
    }
    
    let transactionsTab = tabViewItems[transactionsTabIndex]
    
    guard let transactionsViewController = transactionsTab.viewController as? TransactionsViewController else {
      return reportError(Failure.expectedViewControllerForTab(.transactions))
    }

    self.transactionsViewController = transactionsViewController
    
    transactionsViewController.reportError = { [weak self] error in self?.reportError(error) }
    transactionsViewController.showTransaction = { [weak self] transaction in self?.showTransaction(transaction) }
  }
}

// MARK: - Wallet Listener
extension MainTabViewController: WalletListener {
  func walletUpdated() {
    guard let wallet = wallet else { return reportError(Failure.expectedWalletForTabs) }

    sendViewController?.wallet = wallet
    receiveViewController?.wallet = wallet
    transactionsViewController?.wallet = wallet
    transactionsViewController?.walletUpdated()
  }
}
