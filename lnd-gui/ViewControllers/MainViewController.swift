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
   */
  @IBOutlet weak var connectedBox: NSBox?
  
  // MARK: - Properties
  
  /** chainBalance represents the amount of available value on chain.
   */
  fileprivate var chainBalance: Value? { didSet { updateVisibleBalance() } }
  
  /** channelBalance represents the value of the total funds in channels.
   */
  fileprivate var channelBalance: Value? { didSet { updateVisibleBalance() } }

  /** connected represents whether or not there a connection is present to the backing ln daemon.
   */
  fileprivate var connected: Bool? { didSet { updateConnectedStatus() } }
  
  /** mainTabViewController is the tab view controller for the main view
   */
  weak var mainTabViewController: MainTabViewController?

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
        notification.informativeText = "Received \(payment.amount)"
        notification.soundName = NSUserNotificationDefaultSoundName
        
        NSUserNotificationCenter.default.deliver(notification)
      }
    }
  }
  
  // MARK: - UIViewController
  
  /** initWalletPolling kicks off wallet polling
    
   FIXME: - switch to sockets
   */
  private func initWalletPolling() {
    _ = Timer.scheduledTimer(
      timeInterval: 0.3,
      target: self,
      selector: #selector(refreshInvoices),
      userInfo: nil,
      repeats: true
    )
  }
  
  /** updateConnectedStatus updates the view to reflect the current connected state.
   
   FIXME: - use nicer colors
   */
  func updateConnectedStatus() {
    connectedBox?.fillColor = (connected ?? false) as Bool ? .green : .red
  }

  /** updateVisibleBalance updates the view to show the last retrieved balances
   */
  private func updateVisibleBalance() {
    let chainBalance = (self.chainBalance ?? Value()) as Value
    let channelBalance = (self.channelBalance ?? Value()) as Value
    
    let formattedBalance = "⚡️ Balance: \(channelBalance.formatted) tBTC" +
      ((chainBalance > Value()) ? " (+\(chainBalance.formatted) tBTC chain)" : "")
    
    balanceLabelTextField?.stringValue = formattedBalance
  }

  /** viewDidLoad method initializes the view controller.
   */
  override func viewDidLoad() {
    super.viewDidLoad()
    
    refreshBalances {}
    
    initWalletPolling()
    
    connected = false
    
    balanceLabelTextField?.stringValue = String()
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
    
    mainTabViewController.updateBalance = { [weak self] in self?.refreshBalances() {} }
    
    self.mainTabViewController = mainTabViewController
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
          amount: (payment["amount"] as? NSNumber)?.uint64Value ?? UInt64(),
          confirmed: (payment["confirmed"] as? Bool) ?? false,
          createdAt: createdAt,
          memo: payment["memo"] as? String ?? String(),
          payment: payment["payment"] as! String
        )
      }
      
      DispatchQueue.main.async { self?.receivedPayments = receivedPayments }
    }
    
    task.resume()
  }
}
