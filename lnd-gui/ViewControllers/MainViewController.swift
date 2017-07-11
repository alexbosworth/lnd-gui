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
  // MARK: - @IBOutlets
  
  /** Balance label text field is the balance label that shows the amount of funds available.
   */
  @IBOutlet weak var balanceLabelTextField: NSTextField?

  /** Connected box is the box that reflects the last known connected state to the LN daemon.
   
   FIXME: - switch to active and inactive images
   */
  @IBOutlet weak var connectedBox: NSBox?
  
  // MARK: - Properties

  /** Cents per bitcoin
   */
  var centsPerCoin: Int? { didSet { do { try updateVisibleBalance() } catch { reportError(error) } } }
  
  /** chainBalance represents the amount of available value on chain.
   */
  fileprivate var chainBalance: Tokens? { didSet { do { try updateVisibleBalance() } catch { reportError(error) } } }
  
  /** channelBalance represents the value of the total funds in channels.
   */
  fileprivate var channelBalance: Tokens? { didSet { do { try updateVisibleBalance() } catch { reportError(error) } } }

  /** connected represents whether or not there a connection is present to the backing ln daemon.
   */
  fileprivate var connected: Bool? { didSet { updateConnectedStatus() } }
  
  /** mainTabViewController is the tab view controller for the main view
   */
  weak var mainTabViewController: MainTabViewController?

  /** Report error
   */
  lazy var reportError: (Error) -> () = { _ in }

  /** Show invoice
   */
  lazy var showInvoice: (LightningInvoice) -> () = { _ in }
  
  /** Show payment
   */
  lazy var showPayment: (LightningPayment) -> () = { _ in }
  
  /** Wallet
   */
  lazy var wallet = Wallet()
  
  /** receivedPayments represents payments received.
   
    FIXME: - abstract out notification
   */
  var receivedPayments: [ReceivedPayment]? {
    willSet {
      guard let pastPayments = receivedPayments, let newPayments = newValue else { return }
      
      var payments = [String: ReceivedPayment]()
      
      pastPayments.forEach { payments[$0.payment] = $0 }
      
      let confirmationChanged = newPayments.filter { payment in
        guard let previousInvoice = payments[payment.payment] else { return false }
        
        return previousInvoice.confirmed != payment.confirmed
      }
      
      guard !confirmationChanged.isEmpty else { return }
      
      do { try refreshBalances() } catch { reportError(error) }
      
      confirmationChanged.forEach { payment in
        let notification = NSUserNotification()
        
        notification.title = "Payment for \(payment.memo)"
        notification.informativeText = "Received \(payment.tokens.formatted)"
        notification.soundName = NSUserNotificationDefaultSoundName
        
        NSUserNotificationCenter.default.deliver(notification)
      }
    }
  }
  
  // MARK: - UIViewController
  
  /** updateConnectedStatus updates the view to reflect the current connected state.
   
   FIXME: - use nicer colors
   */
  func updateConnectedStatus() {
    let disconnectedColor = NSColor(calibratedRed: 204 / 255, green: 57 / 255, blue: 57 / 255, alpha: 1)
    let connectedColor = NSColor(calibratedRed: 107 / 255, green: 234 / 255, blue: 107 / 255, alpha: 1)
    
    connectedBox?.fillColor = (connected ?? false) as Bool ? connectedColor : disconnectedColor
  }

  /** updateVisibleBalance updates the view to show the last retrieved balances
   */
  private func updateVisibleBalance() throws {
    let chainBalance = (self.chainBalance ?? Tokens()) as Tokens
    let channelBalance = (self.channelBalance ?? Tokens()) as Tokens
    let formattedBalance: String
    
    let lnBalance = "Lightning Balance: \(channelBalance.formatted) tBTC"
    
    if chainBalance < 100_000 {
      formattedBalance = lnBalance
    } else {
      formattedBalance = "\(lnBalance) - Chain Balance: \(chainBalance.formatted) tBTC"
    }
    
    let amount: String
    
    if let centsPerCoin = centsPerCoin {
      amount = try channelBalance.converted(to: .testUnitedStatesDollars, with: centsPerCoin)
    } else {
      amount = String()
    }
    
    balanceLabelTextField?.stringValue = "\(formattedBalance)\(amount)"
  }

  /** View did load
   */
  override func viewDidLoad() {
    super.viewDidLoad()
    
    do { try refreshBalances() } catch { reportError(error) }
    
    connected = false
    
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
      messageNum += 1
      let msg = "\(messageNum): \(NSDate().description)"
      print("send: \(msg)")
      ws.send(msg)
    }
    ws.event.open = { [weak self] in
      self?.connected = true
      
      self?.refreshInvoices()
      
      do {
        try self?.refreshBalances()

        try self?.refreshHistory()
      } catch {
        self?.reportError(error)
      }
      
      send()
    }
    ws.event.close = { [weak self] code, reason, clean in
      self?.connected = false
      
      ws.open()
    }
    ws.event.error = { error in
      print("error \(error)")
    }
    ws.event.message = { [weak self] message in
      if let message = message as? String { self?.activity(message: message) }
      
      self?.refreshInvoices()

      do {
        try self?.refreshBalances()

        try self?.refreshHistory()
      } catch {
        self?.reportError(error)
      }
    }
  }
}

extension MainViewController {
  /** Received socket message
   */
  func activity(message: String) {
    print("RECEIVED MESSAGE", message)

    guard
      let data = message.data(using: .utf8, allowLossyConversion: false),
      let jsonObject = try? JSONSerialization.jsonObject(with: data, options: .allowFragments),
      let json = jsonObject as? JsonDictionary
      else
    {
      return print("EXPECTED JSON")
    }

    enum RowType: String {
      case chainTransaction = "chain_transaction"
      case channelTransaction = "channel_transaction"
      
      init?(from string: String) {
        if let type = type(of: self).init(rawValue: string) { self = type } else {
          print("UNRECOGNIZED ROW TYPE")
          
          return nil
        }
      }
    }
    
    guard let rowType = json["type"] as? String, let type = RowType(from: rowType) else { return }
    
    switch type {
    case .chainTransaction, .channelTransaction:
      do {
        let transaction = try Transaction(from: json)
        
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
        
        guard let isOutgoing = transaction.isOutgoing else {
          return print("EXPECTED IS OUTGOING")
        }
        
        guard !isOutgoing else { return }
        
        notifyReceived(transaction)
      } catch {
        print(error)
      }
    }
  }
}

extension MainViewController {
  /** Notify of received transaction
   
   FIXME: - when there is no memo, show a nicer received message
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
      
      switch isConfirmed {
      case false:
        notification.title = "Incoming transaction"
        notification.informativeText = "Receiving \(tokens.formatted)"
        
      case true:
        notification.title = "Received funds"
        notification.informativeText = "Received \(tokens.formatted)"
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

    mainTabViewController.walletTokenBalance = { [weak self] in
      guard let chain = self?.chainBalance, let channel = self?.channelBalance else { return nil }
      
      return chain + channel
    }
    
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
    try Daemon.get(from: .balance) { [weak self] result in
      switch result {
      case .data(let data):
        // FIXME: - abstract
        let dataDownloadedAsJson = try? JSONSerialization.jsonObject(with: data, options: .allowFragments)
        
        let balance = dataDownloadedAsJson as? [String: Any]
        
        enum BalanceResponseJsonKey: String {
          case chainBalance = "chain_balance"
          case channelBalance = "channel_balance"
          
          var key: String { return rawValue }
        }
        
        let chainBalance = (balance?[BalanceResponseJsonKey.chainBalance.key] as? NSNumber)?.tokensValue
        let channelBalance = (balance?[BalanceResponseJsonKey.channelBalance.key] as? NSNumber)?.tokensValue
        
        DispatchQueue.main.async {
          self?.chainBalance = chainBalance
          self?.channelBalance = channelBalance
        }
        
      case .error(let error):
        self?.reportError(error)
      }
    }
  }
  
  /** refreshInvoices performs a data request to the LN daemon to fetch information about outstanding invoices.
   
   // FIXME: - switch to sockets
   */
  func refreshInvoices() {
    let url = URL(string: "http://localhost:10553/v0/invoices/")!
    let session = URLSession.shared
    
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    
    let task = session.dataTask(with: request) { [weak self] data, urlResponse, error in
      guard error == nil else { return DispatchQueue.main.async { self?.connected = false } }
      
      guard (urlResponse as? HTTPURLResponse)?.statusCode == 200 else {
        return DispatchQueue.main.async { self?.connected = false }
      }
      
      guard let data = data else { return print("Expected data") }
      
      guard let jsonObject = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) else {
        return print("INVALID JSON")
      }
      
      guard let json = jsonObject as? [[String: Any]] else {
        return print("INVALID JSON PARSED")
      }
      
      DispatchQueue.main.async { self?.connected = true }
      
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
      
      DispatchQueue.main.async { self?.receivedPayments = receivedPayments }
    }
    
    task.resume()
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
