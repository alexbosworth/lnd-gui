//
//  MainViewController.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 3/6/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Cocoa

/** MainViewController is the controller for the main view.
 
 FIXME: - cleanup, comment
 */
class MainViewController: NSViewController {
  // MARK: - @IBActions
  
  /** Pressed daemons button
   */
  @IBAction func pressedDaemonsButton(_ button: NSButton) {
    showDaemons()
  }
  
  // MARK: - @IBOutlets
  
  /** Balance label text field is the balance label that shows the amount of funds available.
   */
  @IBOutlet weak var balanceLabelTextField: NSTextField?

  /** Connected box is the box that reflects the last known connected state to the LN daemon.
   */
  @IBOutlet weak var connectivityStatusButton: NSButton?
  
  /** Fiat conversion rate text field
   */
  @IBOutlet weak var priceTextField: NSTextField?
  
  // MARK: - Properties

  /** connected represents whether or not there a connection is present to the backing ln daemon.
   */
  fileprivate var connected: ConnectivityStatus = .initializing { didSet { updateConnectedStatus() } }
  
  /** mainTabViewController is the tab view controller for the main view
   */
  weak var mainTabViewController: MainTabViewController?

  /** Report error
   */
  lazy var reportError: (Error) -> () = { _ in }

  /** Show daemons
   */
  lazy var showDaemons: () -> () = {}
  
  /** Show invoice
   */
  lazy var showInvoice: (LightningInvoice) -> () = { _ in }
  
  /** Show payment
   */
  lazy var showPayment: (LightningPayment) -> () = { _ in }
  
  /** Wallet
   */
  var wallet: Wallet?
}

// MARK: - Errors
extension MainViewController {
  enum Failure: Error {
    case expectedMainTabViewController
    case expectedWallet
  }
}

// MARK: - Navigation
extension MainViewController {
  /** prepare performs setup for the navigated-to view controller.
   */
  override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
    super.prepare(for: segue, sender: sender)
    
    guard let mainTabViewController = segue.destinationController as? MainTabViewController else {
      return reportError(Failure.expectedMainTabViewController)
    }
    
    mainTabViewController.reportError = { [weak self] in self?.reportError($0) }
    mainTabViewController.showInvoice = { [weak self] invoice in self?.showInvoice(invoice) }
    mainTabViewController.showPayment = { [weak self] payment in self?.showPayment(payment) }
    mainTabViewController.wallet = wallet
    
    self.mainTabViewController = mainTabViewController
  }
  
  /** Show network connections
   */
  func showConnections() {
    guard let mainTabViewController = mainTabViewController else {
      return reportError(Failure.expectedMainTabViewController)
    }
    
    mainTabViewController.showConnections()
  }
}

// MARK: - WalletListener
extension MainViewController: WalletListener {
  /** Wallet was updated
   */
  func walletUpdated() {
    guard let wallet = wallet else {
      return reportError(Failure.expectedWallet)
    }
    
    mainTabViewController?.wallet = wallet
    mainTabViewController?.walletUpdated()
    updateConnectedStatus()
    
    do { try updateVisibleBalance() } catch { reportError(error) }
    
    mainTabViewController?.tabViewItems.map { $0 as? WalletListener }.forEach { $0?.walletUpdated() }
  }
}

// MARK: - UIViewController
extension MainViewController {
  /** updateConnectedStatus updates the view to reflect the current connected state.
   */
  func updateConnectedStatus() {
    let connectivity = (wallet?.realtimeConnectionStatus ?? .initializing) as ConnectivityStatus
    
    connectivityStatusButton?.image = connectivity.statusImage
    connectivityStatusButton?.toolTip = connectivity.localizedDescription
  }
  
  /** updateVisibleBalance updates the view to show the last retrieved balances
   
   FIXME: - indicate lack of FX rate when applicable
   */
  fileprivate func updateVisibleBalance() throws {
    let chainBalance = (wallet?.balances?.chainTokens ?? Tokens()) as Tokens
    let channelBalance = (wallet?.balances?.channelTokens ?? Tokens()) as Tokens
    let pendingChainBalance = (wallet?.balances?.pendingChainTokens ?? Tokens()) as Tokens
    let pendingChannelBalance = (wallet?.balances?.pendingChannelTokens ?? Tokens()) as Tokens
    
    let totalBalance = chainBalance + channelBalance
    let pendingBalance = pendingChannelBalance + pendingChainBalance
    
    let formattedBalance = "Balance: \(totalBalance.formatted) tBTC"
    
    let amount: String
    
    if let centsPerCoin = wallet?.centsPerCoin {
      let currencyFormatter = NumberFormatter()
      currencyFormatter.usesGroupingSeparator = true
      currencyFormatter.numberStyle = .currency
      // localize to your grouping and decimal separator
      currencyFormatter.locale = .current
      let dollarsPerCoin: Double = Double(centsPerCoin) / Double(100)

      let priceString = (currencyFormatter.string(from: NSNumber(value: dollarsPerCoin)) ?? String()) as String
      
      priceTextField?.stringValue = "1 tBTC = \(priceString)"
      
      amount = try totalBalance.converted(to: .testUnitedStatesDollars, with: centsPerCoin)
    } else {
      priceTextField?.stringValue = String()

      amount = String()
    }
    
    balanceLabelTextField?.stringValue = "\(formattedBalance)\(amount)"
    
    if pendingBalance != Tokens() {
      balanceLabelTextField?.stringValue = "\(formattedBalance)\(amount) (+\(pendingBalance.formatted(with: .testBitcoin)) Pending)"
    }
    
    mainTabViewController?.walletUpdated()
  }
  
  /** View did load
   */
  override func viewDidLoad() {
    super.viewDidLoad()
    
    balanceLabelTextField?.stringValue = String()
  }
}
