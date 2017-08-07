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

  /** Cents per bitcoin
   */
  var centsPerCoin: Int? { didSet { do { try updateVisibleBalance() } catch { reportError(error) } } }

  /** connected represents whether or not there a connection is present to the backing ln daemon.
   */
  fileprivate var connected: ConnectivityStatus = .initializing { didSet { updateConnectedStatus() } }
  
  /** mainTabViewController is the tab view controller for the main view
   */
  weak var mainTabViewController: MainTabViewController?
  
  /** Payments received
   
   FIXME: - abstract out notification
   */
  var receivedPayments: [ReceivedPayment]? {
    willSet { do { try willUpdateReceivedPayments(with: newValue) } catch { reportError(error) } }
  }

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
  
  lazy var updateConnectivity: (ConnectivityStatus) -> () = { _ in }
  
  /** Wallet
   */
  lazy var wallet = Wallet()

  /** Wallet tokens
   */
  fileprivate var walletTokens: WalletBalances? {
    didSet { do { try updateVisibleBalance() } catch { reportError(error) } }
  }
}

extension MainViewController {
  
  /** Received socket message
   */
  func receivedWalletServiceMessage(_ message: String) throws {
    let walletObject = try WalletObject(from: message.data(using: .utf8, allowLossyConversion: false))
    
    switch walletObject {
    case .transaction(let transaction):
      switch transaction {
      case .blockchain(let chainTransaction) where chainTransaction.isConfirmed == false:
        wallet.unconfirmedTransactions += [transaction]
        
      case .blockchain(let chainTransaction) where chainTransaction.isConfirmed == true:
        wallet.unconfirmedTransactions = wallet.unconfirmedTransactions.filter { $0 != transaction }
        
      case .blockchain(_):
        break
        
      case .lightning(_):
        break
      }
      
      guard let isOutgoing = transaction.isOutgoing, !isOutgoing else { return }
      
      notifyReceived(transaction)
    }
  }
}

extension MainViewController {
  /** Notify of received transaction
   
   FIXME: - when there is no memo, show a nicer received message
   FIXME: - show units and fiat conversion
   */
  func notifyReceived(_ transaction: Transaction) {
    switch transaction {
    case .blockchain(let chainTransaction):
      guard
        let isConfirmed = chainTransaction.isConfirmed,
        let tokens = chainTransaction.sendTokens,
        chainTransaction.isOutgoing == false
        else
      {
        break
      }
      
      let notification = NSUserNotification()

      let formattedTokens: String
      
      if let centsPerCoin = centsPerCoin {
        do {
          formattedTokens = try tokens.converted(to: .testUnitedStatesDollars, with: centsPerCoin)
        } catch {
          reportError(error)
          
          formattedTokens = tokens.formatted
        }
      } else {
        formattedTokens = tokens.formatted
      }
      
      switch isConfirmed {
      case false:
        notification.title = "Incoming transaction"
        notification.informativeText = "Receiving \(formattedTokens)"
        
      case true:
        notification.title = "Received funds"
        notification.informativeText = "Received \(formattedTokens)"
      }
      
      notification.soundName = NSUserNotificationDefaultSoundName
      
      NSUserNotificationCenter.default.deliver(notification)
      
    case .lightning(let lightningTransaction):
      switch lightningTransaction {
      case .invoice(let invoice):
        guard let memo = invoice.memo else { break }
        
        let notification = NSUserNotification()
        
        notification.title = "Payment for \(memo)"
        notification.informativeText = "Received \(invoice.tokens.formatted)"
        notification.soundName = NSUserNotificationDefaultSoundName
        
        NSUserNotificationCenter.default.deliver(notification)
        
      case .payment(_):
        break
      }
    }
  }
}

// MARK: - Errors
extension MainViewController {
  enum Failure: String, Error {
    case expectedMainTabViewController
  }
}

// MARK: - Navigation
extension MainViewController {
  /** prepare performs setup for the navigated-to view controller.
   */
  override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
    super.prepare(for: segue, sender: sender)
    
    guard let mainTabViewController = segue.destinationController as? MainTabViewController else {
      return print(Failure.expectedMainTabViewController.localizedDescription)
    }
    
    mainTabViewController.centsPerCoin = { [weak self] in self?.centsPerCoin }
    
    mainTabViewController.reportError = { [weak self] in self?.reportError($0) }
    
    mainTabViewController.showInvoice = { [weak self] invoice in self?.showInvoice(invoice) }

    mainTabViewController.showPayment = { [weak self] payment in self?.showPayment(payment) }
    
    mainTabViewController.updateBalance = { [weak self] in
      do { try self?.refreshBalances() } catch { self?.reportError(error) }
    }

    mainTabViewController.walletTokenBalance = { [weak self] in self?.walletTokens?.spendableBalance }
    
    self.mainTabViewController = mainTabViewController
  }
  
  func showConnections() {
    guard let mainTabViewController = mainTabViewController else {
      return print("ERROR", "expected main tab view controller")
    }
    
    mainTabViewController.showConnections()
  }
}

// MARK: - Networking
extension MainViewController {
  /** Refresh exchange rate
   */
  func refreshExchangeRate() throws {
    try Daemon.get(from: .exchangeRate(.testUnitedStatesDollars)) { [weak self] result in
      switch result {
      case .data(let data):
        let dataDownloadedAsJson = try? JSONSerialization.jsonObject(with: data, options: .allowFragments)
        
        let json = dataDownloadedAsJson as? [String: Any]
        
        enum ExchangeRateResponseJsonKey: String {
          case centsPerBitcoin = "cents_per_bitcoin"
          
          var key: String { return rawValue }
        }
        
        let centsPerBitcoin = (json?[ExchangeRateResponseJsonKey.centsPerBitcoin.key] as? NSNumber)?.intValue

        DispatchQueue.main.async { self?.centsPerCoin = centsPerBitcoin }
        
      case .error(let error):
        self?.reportError(error)
      }
    }
  }
  
  /** refreshBalances updates the chain and channel balance from the LN daemon.
   
   FIXME: - switch to sockets
   */
  func refreshBalances() throws {
    try Daemon.getBalances { [weak self] result in
      switch result {
      case .balances(let balances):
        self?.walletTokens = balances
        
      case .error(let error):
        self?.reportError(error)
      }
    }
  }
  
  /** refreshInvoices performs a data request to the LN daemon to fetch information about outstanding invoices.
   
   // FIXME: - switch to sockets
   */
  func refreshInvoices() throws {
    try Daemon.get(from: .invoices) { [weak self] result in
      switch result {
      case .data(let data):
        
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) else {
          return print("INVALID JSON")
        }
        
        guard let json = jsonObject as? [[String: Any]] else {
          return print("INVALID JSON PARSED")
        }
        
        self?.connected = .connected
        
        let receivedPayments: [ReceivedPayment] = json.map { payment in
          let dateFormatter = DateFormatter()
          dateFormatter.locale = Locale(identifier: "en_US_POSIX")
          dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
          let createdAtString = payment["created_at"] as! String
          let createdAt = dateFormatter.date(from: createdAtString)!
          
          return ReceivedPayment(
            confirmed: (payment["confirmed"] as? Bool) ?? false,
            createdAt: createdAt,
            memo: payment["memo"] as? String ?? String(),
            payment: payment["payment_request"] as! String,
            tokens: ((payment["tokens"] as? NSNumber)?.tokensValue ?? Tokens()) as Tokens
          )
        }
        
        self?.receivedPayments = receivedPayments
        
      case .error(let error):
        self?.reportError(error)
      }
    }
  }
}

extension MainViewController {
  enum RefreshHistoryFailure: Error {
    case expectedHistoryData
  }
  
  func refreshHistory() throws {
    try Daemon.get(from: .history) { [weak self] result in
      switch result {
      case .data(let data):
        let dataDownloadedAsJson = try? JSONSerialization.jsonObject(with: data, options: .allowFragments)
        
        guard let history = dataDownloadedAsJson as? [JsonDictionary] else {
          self?.reportError(RefreshHistoryFailure.expectedHistoryData)
          
          break
        }

        do {
          let transactions = try history.map { try Transaction(from: $0) }
          
          DispatchQueue.main.async {
            self?.wallet.transactions = transactions
            
            guard let wallet = self?.wallet else { return }
            
            NSApplication.shared().windows.forEach { window in
              guard let walletListener = window.contentViewController as? WalletListener else { return }
              
              walletListener.wallet(updated: wallet)
            }
            
            self?.mainTabViewController?.tabViewItems.forEach { tabViewItem in
              guard let walletListener = tabViewItem.viewController as? WalletListener else { return }
              
              walletListener.wallet(updated: wallet)
            }
          }
        } catch {
          self?.reportError(error)
        }
        
      case .error(let error):
        self?.reportError(error)
      }
    }
  }
}

// MARK: - UIViewController
extension MainViewController {
  /** receivedPayment is about to be updated
   */
  func willUpdateReceivedPayments(with payments: [ReceivedPayment]?) throws {
    guard let pastPayments = receivedPayments, let newPayments = payments else { return }
    
    var payments = [String: ReceivedPayment]()
    
    pastPayments.forEach { payments[$0.payment] = $0 }
    
    let confirmationChanged = newPayments.filter { payment in
      guard let previousInvoice = payments[payment.payment] else { return false }
      
      return previousInvoice.confirmed != payment.confirmed
    }
    
    guard !confirmationChanged.isEmpty else { return }
    
    do { try refreshBalances() } catch { reportError(error) }
    
    try confirmationChanged.forEach { payment in
      let notification = NSUserNotification()
      
      notification.title = "Received payment for \(payment.memo)"
      notification.soundName = NSUserNotificationDefaultSoundName
      
      let fiatConversionNotice: String
      
      if let centsPerCoin = centsPerCoin {
        fiatConversionNotice = try payment.tokens.converted(to: .testUnitedStatesDollars, with: centsPerCoin)
      } else {
        fiatConversionNotice = String()
      }
      
      notification.informativeText = "+\(payment.tokens.formatted)\(fiatConversionNotice)"
      
      NSUserNotificationCenter.default.deliver(notification)
    }
  }
  
  /** updateConnectedStatus updates the view to reflect the current connected state.
   */
  func updateConnectedStatus() {
    updateConnectivity(connected)
    
    connectivityStatusButton?.image = connected.statusImage
    connectivityStatusButton?.toolTip = connected.localizedDescription
  }
  
  /** updateVisibleBalance updates the view to show the last retrieved balances
   */
  fileprivate func updateVisibleBalance() throws {
    let chainBalance = (self.walletTokens?.chainTokens ?? Tokens()) as Tokens
    let channelBalance = (self.walletTokens?.channelTokens ?? Tokens()) as Tokens
    let pendingChainBalance = (walletTokens?.pendingChainTokens ?? Tokens()) as Tokens
    let pendingChannelBalance = (walletTokens?.pendingChannelTokens ?? Tokens()) as Tokens
    
    let totalBalance = chainBalance + channelBalance
    let pendingBalance = pendingChannelBalance + pendingChainBalance
    
    let formattedBalance = "Balance: \(totalBalance.formatted) tBTC"
    
    let amount: String
    
    if let centsPerCoin = centsPerCoin {
      let currencyFormatter = NumberFormatter()
      currencyFormatter.usesGroupingSeparator = true
      currencyFormatter.numberStyle = .currency
      // localize to your grouping and decimal separator
      currencyFormatter.locale = .current
      let dollarsPerCoin: Double = Double(centsPerCoin) / Double(100)

      let priceString = (currencyFormatter.string(from: NSNumber(value: dollarsPerCoin)) ?? String()) as String
      
      priceTextField?.stringValue = "1 BTC = \(priceString)"
      
      amount = try totalBalance.converted(to: .testUnitedStatesDollars, with: centsPerCoin)
    } else {
      priceTextField?.stringValue = String()

      amount = String()
    }
    
    balanceLabelTextField?.stringValue = "\(formattedBalance)\(amount)"
    
    if pendingBalance != Tokens() {
      balanceLabelTextField?.stringValue = "\(formattedBalance)\(amount) (+\(pendingBalance.formatted(with: .testBitcoin)) Pending)"
    }
    
    mainTabViewController?.sendViewController?.wallet(updated: wallet)
  }
  
  /** View did load
   */
  override func viewDidLoad() {
    super.viewDidLoad()
    
    do { try refreshBalances() } catch { reportError(error) }
    
    balanceLabelTextField?.stringValue = String()
    
    initWalletServiceConnection()
    
    do {
      try refreshHistory()
      
      try refreshExchangeRate()
    } catch {
      reportError(error)
    }
  }
  
  /** Initialize the wallet service connection
   */
  func initWalletServiceConnection(){
    var messageNum = 0
    let ws = WebSocket("ws://localhost:10554")
    let send: () -> () = {
      // FIXME: - short circuit daemon POST calls to use this socket when available
      messageNum += 1
      let msg = "\(messageNum): \(NSDate().description)"
      print("send: \(msg)")
      ws.send(msg)
    }
    ws.event.open = { [weak self] in
      self?.connected = .connected
      
      do {
        // FIXME: - abstract and combine, avoid excessive polling
        try self?.refreshInvoices()
        
        try self?.refreshBalances()
        
        try self?.refreshHistory()
      } catch {
        self?.reportError(error)
      }
      
      send()
    }
    ws.event.close = { [weak self] code, reason, clean in
      self?.connected = .disconnected
      
      ws.open()
    }
    ws.event.error = { error in
      print("error \(error)")
    }
    ws.event.message = { [weak self] message in
      guard let message = message as? String else { return }
      
      do {
        try self?.receivedWalletServiceMessage(message)
      
        // FIXME: - avoid refreshing and just use push messages, unless there is something missed
        try self?.refreshInvoices()
      
        try self?.refreshBalances()
        
        try self?.refreshHistory()
      } catch {
        self?.reportError(error)
      }
    }
  }
}
