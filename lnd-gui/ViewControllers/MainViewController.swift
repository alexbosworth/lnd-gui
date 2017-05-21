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
  
  /** balanceLabelTextField is the balance label that shows the amount of funds available.
   */
  @IBOutlet weak var balanceLabelTextField: NSTextField?

  /** connectedBox is the box that reflects the last known connected state to the LN daemon.
   
   FIXME: - switch to active and inactive images
   */
  @IBOutlet weak var connectedBox: NSBox?
  
  // MARK: - Properties
  
  /** chainBalance represents the amount of available value on chain.
   */
  fileprivate var chainBalance: Tokens? { didSet { updateVisibleBalance() } }
  
  /** channelBalance represents the value of the total funds in channels.
   */
  fileprivate var channelBalance: Tokens? { didSet { updateVisibleBalance() } }

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
  lazy var showInvoice: (Invoice) -> () = { _ in }
  
  /** Show payment
   */
  lazy var showPayment: (Transaction) -> () = { _ in }
  
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
      
      refreshBalances() {}
      
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
  private func updateVisibleBalance() {
    let chainBalance = (self.chainBalance ?? Tokens()) as Tokens
    let channelBalance = (self.channelBalance ?? Tokens()) as Tokens
    let formattedBalance: String
    
    let lnBalance = "Lightning Balance: \(channelBalance.formatted) tBTC"
    
    if chainBalance < 100_000 {
      formattedBalance = lnBalance
    } else {
      formattedBalance = "\(lnBalance) - Chain Balance: \(chainBalance.formatted) tBTC"
    }
    
    balanceLabelTextField?.stringValue = formattedBalance
  }

  /** View did load
   */
  override func viewDidLoad() {
    super.viewDidLoad()
    
    refreshBalances {}
    
    connected = false
    
    balanceLabelTextField?.stringValue = String()
    
    initWalletServiceConnection()

    refreshHistory()
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
      
      self?.refreshHistory()
      
      self?.refreshBalances() {}
      
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

      self?.refreshBalances() {}
      
      self?.refreshHistory()
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
      let json = jsonObject as? [String: Any]
      else
    {
      return
    }

    enum RowType: String {
      case chainTransaction = "chain_transaction"
      case channelTransaction = "channel_transaction"
      
      init?(from string: String) {
        if let type = type(of: self).init(rawValue: string) { self = type } else { return nil }
      }
    }
    
    guard let rowType = json["type"] as? String, let type = RowType(from: rowType) else { return }
    
    switch type {
    case .chainTransaction, .channelTransaction:
      do {
        let transaction = try Transaction(from: json)
        
        if type == .chainTransaction && !transaction.confirmed { wallet.unconfirmedTransactions += [transaction] }

        if transaction.confirmed && type == .chainTransaction {
          wallet.unconfirmedTransactions = wallet.unconfirmedTransactions.filter { $0 != transaction }
        }
        
        if !transaction.outgoing { notifyReceived(transaction) }
      } catch {
        print(error)
      }
    }
  }
}

extension MainViewController {
  /** Notify of received transaction
   */
  func notifyReceived(_ transaction: Transaction) {
    switch transaction.destination {
    case .chain:
      guard !transaction.outgoing else { break }
      
      let notification = NSUserNotification()
      
      switch transaction.confirmed {
      case false:
        notification.title = "Incoming transaction"
        notification.informativeText = "Receiving \(transaction.tokens.formatted)"

      case true:
        notification.title = "Received funds"
        notification.informativeText = "Received \(transaction.tokens.formatted)"
      }
      
      notification.soundName = NSUserNotificationDefaultSoundName
      
      NSUserNotificationCenter.default.deliver(notification)
      
    case .received(memo: let memo):
      let notification = NSUserNotification()
      
      notification.title = "Payment for \(memo)"
      notification.informativeText = "Received \(transaction.tokens.formatted)"
      notification.soundName = NSUserNotificationDefaultSoundName
      
      NSUserNotificationCenter.default.deliver(notification)
      
    case .sent(_, _):
      break
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
    
    mainTabViewController.showInvoice = { [weak self] invoice in self?.showInvoice(invoice) }

    mainTabViewController.showPayment = { [weak self] payment in self?.showPayment(payment) }
    
    mainTabViewController.updateBalance = { [weak self] in self?.refreshBalances() {} }
    
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
  
  /** refreshBalances updates the chain and channel balance from the LN daemon.
   
   FIXME: - switch to sockets
   */
  func refreshBalances(completion: (() -> ())?) {
    let url = URL(string: "http://localhost:10553/v0/balance/")!
    let session = URLSession.shared
    
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.cachePolicy = .reloadIgnoringCacheData
    
    let task = session.dataTask(with: request) { [weak self] data, urlResponse, error in
      guard let balanceData = data else { return print("Expected balance data") }
      
      let dataDownloadedAsJson = try? JSONSerialization.jsonObject(with: balanceData, options: .allowFragments)
      
      let balance = dataDownloadedAsJson as? [String: Any]
      
      enum BalanceResponseJsonKey: String {
        case chainBalance = "chain_balance"
        case channelBalance = "channel_balance"
        
        var key: String { return rawValue }
      }
      
      let chainBalance = (balance?[BalanceResponseJsonKey.chainBalance.key] as? NSNumber)?.uint64Value
      let channelBalance = (balance?[BalanceResponseJsonKey.channelBalance.key] as? NSNumber)?.uint64Value
      
      DispatchQueue.main.async {
        self?.chainBalance = chainBalance
        self?.channelBalance = channelBalance
      }
      
      completion?()
    }
    
    task.resume()
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
          self?.wallet.transactions = transactions

          guard let wallet = self?.wallet else { return }
          
          self?.mainTabViewController?.tabViewItems.forEach { tabViewItem in
            guard let walletListener = tabViewItem.viewController as? WalletListener else { return }

            walletListener.wallet(updated: wallet)
          }
        }
      } catch {
        print("Failed to parse transaction history \(error)")
      }
    }
    
    task.resume()
  }
}
