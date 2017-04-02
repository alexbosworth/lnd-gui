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
  
  /** channelBalance is the value of the total funds in channels.
   
   FIXME: - use localizable string
   */
  private var channelBalance: Value? {
    didSet {
      balanceLabelTextField?.stringValue = "Balance: \(((channelBalance ?? Value()) as Value).formatted) tBTC"
    }
  }
  
  /** mainTabViewController is the tab view controller for the main view
   */
  weak var mainTabViewController: MainTabViewController?

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
  
  /** viewDidLoad method initializes the view controller.
   */
  override func viewDidLoad() {
    super.viewDidLoad()
    
    refreshChannelBalance {}
    
    initWalletPolling()
  }

  @IBOutlet weak var balanceLabelTextField: NSTextField?
  
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
      guard let data = data else { return print("Expected data") }
      
      guard let jsonObject = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) else {
        return print("INVALID JSON")
      }
      
      guard let json = jsonObject as? [[String: Any]] else {
        return print("INVALID JSON PARSED")
      }
      
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
      
      let channelBalance = (balance?["channel_balance"] as? NSNumber)?.uint64Value
      
      DispatchQueue.main.async { self?.channelBalance = channelBalance }
      
      completion?()
    }
    
    task.resume()
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
    
    mainTabViewController.updateBalance = { [weak self] in self?.refreshChannelBalance() {} }
    
    self.mainTabViewController = mainTabViewController
  }
}
