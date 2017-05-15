//
//  MainTabViewController.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 3/5/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Cocoa

typealias StoryboardIdentifier = String

/** MainTabViewController is the overall tab controller.
 */
class MainTabViewController: NSTabViewController {  
  // MARK: - Properties
  
  var connectionsViewController: ConnectionsViewController?

  var receiveViewController: ReceiveViewController?
  
  var sendViewController: SendViewController?
  
  lazy var showInvoice: (Invoice) -> () = { _ in }
  
  var transactionsViewController: TransactionsViewController?
  
  /** updateBalance closure triggers a balance update
   */
  var updateBalance: (() -> ())?
}

// MARK: - Failures
extension MainTabViewController {
  /** Failure defines an encountered error.
   */
  enum Failure: String, Error {
    case expectedTab
    case expectedViewController
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
  
  func showConnections() {
    guard let connectionsViewController = connectionsViewController else {
      return print("ERROR", "expected connections view controller")
    }
    
    let connectionsTabIndex = tabView.indexOfTabViewItem(withIdentifier: Tab.connections.storyboardIdentifier)
    
    guard connectionsTabIndex == NSNotFound else { return selectedTabViewItemIndex = connectionsTabIndex }
    
    let insertionIndex = tabViewItems.endIndex

    // FIXME: - insert at a deterministic position
    insertChildViewController(connectionsViewController, at: insertionIndex)
    
    selectedTabViewItemIndex = insertionIndex
  }

  func showTransaction(_ transaction: Transaction) {
    switch transaction.destination {
    case .chain, .sent(_, _):
      break
      
    case .received(let invoice):
      return showInvoice(invoice)
    }
    
    switch transaction.outgoing {
    case false:
      let receiveTabIndex = tabView.indexOfTabViewItem(withIdentifier: Tab.receive.storyboardIdentifier)

      guard receiveTabIndex != NSNotFound else { return print("ERROR", "expected receive tab") }

      selectedTabViewItemIndex = receiveTabIndex

      guard let receiveViewController = receiveViewController else { return print("ERROR", "expected receive vc") }

      do {
        switch transaction.confirmed {
        case false:
          receiveViewController.invoice = try Invoice(from: transaction)
          
        case true:
          receiveViewController.paidInvoice = transaction
        }
        
      } catch {
        print("ERROR", error)
      }
    
    case true:
      let sendTabIndex = tabView.indexOfTabViewItem(withIdentifier: Tab.send.storyboardIdentifier)
      
      guard sendTabIndex != NSNotFound else { return print("ERROR", "expected send tab") }
      
      selectedTabViewItemIndex = sendTabIndex
      
      guard let sendViewController = sendViewController else { return print("ERROR", "expected send vc") }
      
      sendViewController.settledTransaction = transaction
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
      
      removeChildViewController(at: connectionsTabIndex)
    }
    
    let receiveTabIndex = tabView.indexOfTabViewItem(withIdentifier: Tab.receive.storyboardIdentifier)
    
    guard receiveTabIndex < tabViewItems.endIndex && receiveTabIndex >= tabViewItems.startIndex else {
      return print("ERROR", Failure.expectedTab)
    }
    
    let receiveTab = tabViewItems[receiveTabIndex]
    
    guard let receiveViewController = receiveTab.viewController as? ReceiveViewController else {
      return print("ERROR", Failure.expectedViewController)
    }
    
    self.receiveViewController = receiveViewController
    
    let sendTabIndex = tabView.indexOfTabViewItem(withIdentifier: Tab.send.storyboardIdentifier)
    
    guard sendTabIndex < tabViewItems.endIndex && sendTabIndex >= tabViewItems.startIndex else {
      return print("ERROR", Failure.expectedTab)
    }
    
    let sendTab = tabViewItems[sendTabIndex]
    
    guard let sendViewController = sendTab.viewController as? SendViewController else {
      return print("ERROR", Failure.expectedViewController)
    }
    
    self.sendViewController = sendViewController
    
    sendViewController.updateBalance = { [weak self] in self?.updateBalance?() }

    let transactionsTabIndex = tabView.indexOfTabViewItem(withIdentifier: Tab.transactions.storyboardIdentifier)
    
    guard transactionsTabIndex < tabViewItems.endIndex, transactionsTabIndex >= tabViewItems.startIndex else {
      return print("ERROR", Failure.expectedTab)
    }
    
    let transactionsTab = tabViewItems[transactionsTabIndex]
    
    guard let transactionsViewController = transactionsTab.viewController as? TransactionsViewController else {
      return print("ERROR", Failure.expectedViewController)
    }

    self.transactionsViewController = transactionsViewController
    
    transactionsViewController.showTransaction = { [weak self] transaction in
      self?.showTransaction(transaction)
    }
  }
}
