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
  // MARK: - Properties
  
  private var chainBalance: Value? {
    didSet {
      updateVisibleBalance()
    }
  }
  
  /** channelBalance is the value of the total funds in channels.
   
   FIXME: - use localizable string
   */
  private var channelBalance: Value? {
    didSet {
      updateVisibleBalance()
    }
  }
  
  private var connected: Bool? {
    didSet {
      updateConnectedStatus()
    }
  }
  
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
  
  /** viewDidLoad method initializes the view controller.
   */
  override func viewDidLoad() {
    super.viewDidLoad()
    
    refreshChannelBalance {}
    
    initWalletPolling()
    
    connected = false
    
    balanceLabelTextField?.stringValue = String()
  }
  
  private func updateVisibleBalance() {
    let chainBalance = (self.chainBalance ?? Value()) as Value
    let channelBalance = (self.channelBalance ?? Value()) as Value
    
    let formattedBalance = "⚡️ Balance: \(channelBalance.formatted) tBTC" +
      ((chainBalance > Value()) ? " (+\(chainBalance.formatted) tBTC chain)" : "")
    
    balanceLabelTextField?.stringValue = formattedBalance
  }
  
  weak var mainTabViewController: MainTabViewController?
  
  override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
    super.prepare(for: segue, sender: sender)

    guard let mainTabViewController = segue.destinationController as? MainTabViewController else {
      return print("Expected main tab view controller")
    }
    
    mainTabViewController.updateBalance = { [weak self] in self?.refreshChannelBalance() {} }
    
    self.mainTabViewController = mainTabViewController
  }

  @IBOutlet weak var balanceLabelTextField: NSTextField?
  
  @IBOutlet weak var connectedBox: NSBox?
  
  struct ReceivedPayment {
    let amount: UInt64
    let confirmed: Bool
    let createdAt: Date
    let memo: String
    let payment: String
  }
  
  // FIXME: - switch to sockets
  public func refreshInvoices() {
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
      
      refreshChannelBalance() {}
      
      confirmationChanged.forEach { payment in
        let notification = NSUserNotification()
        
        notification.title = "Payment for \(payment.memo)"
        notification.informativeText = "Received \(payment.amount)"
        notification.soundName = NSUserNotificationDefaultSoundName
        
        NSUserNotificationCenter.default.deliver(notification)
      }
    }
  }
  
  func updateConnectedStatus() {
    let connected = (self.connected ?? false) as Bool
    
    connectedBox?.fillColor = connected ? .green : .red
  }
  
  // FIXME: - switch to sockets
  func refreshChannelBalance(completion: (() -> ())?) {
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

}
