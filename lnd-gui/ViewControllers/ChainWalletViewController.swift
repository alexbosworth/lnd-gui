//
//  ChainWalletViewController.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 4/17/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Cocoa

/** Chain wallet view controller
 
  FIXME: - eliminate this view
 */
class ChainWalletViewController: NSViewController {
  /** User pressed the button to send funds on the chain.
   */
  @IBAction func pressedSendButton(_ button: NSButton) {
    guard let tokensString = sendAmountTextField?.stringValue, let tokens = Float(tokensString), tokens > Float() else {
      return
    }

    guard let address = sendToAddressTextField?.stringValue, !address.isEmpty else {
      return
    }
    
    send(to: address, tokens: Tokens(tokens * 100_000_000))
  }
  
  @IBOutlet weak var balanceTextField: NSTextField?
  
  @IBOutlet weak var receiveAddressTextField: NSTextField?
  
  @IBOutlet weak var sendToAddressTextField: NSTextField?
  
  @IBOutlet weak var sendAmountTextField: NSTextField?
  
  var address: String? {
    didSet {
      receiveAddressTextField?.stringValue = (address ?? String()) as String
    }
  }
  
  var chainBalance: Tokens? {
    didSet {
      guard let balance = chainBalance else {
        balanceTextField?.stringValue = " "
        
        return
      }
      
      balanceTextField?.stringValue = "\(balance.formatted) tBTC"
    }
  }
  
  override func viewDidAppear() {
    super.viewDidAppear()

    populateAddress()
    
    refreshChainBalance()
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    // Do view setup here.
  }
}

extension ChainWalletViewController {
  func refreshChainBalance() {
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
      
      let chainBalance = (balance?[BalanceResponseJsonKey.chainBalance.key] as? NSNumber)?.tokensValue
      
      DispatchQueue.main.async {
        self?.chainBalance = chainBalance
      }
    }
    
    task.resume()
  }
  
  func send(to address: String, tokens: Tokens) {
    print("SEND TOKENS", tokens)
    
    let session = URLSession.shared
    let sendUrl = URL(string: "http://localhost:10553/v0/transactions/")!
    var sendUrlRequest = URLRequest(url: sendUrl, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 30)
    sendUrlRequest.httpMethod = "POST"
    sendUrlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let data = "{\"address\": \"\(address)\", \"tokens\": \"\(tokens)\"}".data(using: .utf8)
    
    let sendTask = session.uploadTask(with: sendUrlRequest, from: data) { [weak self] data, urlResponse, error in
      if let error = error {
        return print("ERROR \(error)")
      }
      
      guard let data = data else {
        return print("Expected data")
      }
      
      do {
        guard let json = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] else {
          return print("EXPECTED JSON")
        }

        guard let transactionId = json["transaction_id"] as? String else {
          return print("EXPECTED TRANSACTION ID")
        }

        print("TRANSACTION SENT \(transactionId)")
      } catch {
        return print(error)
      }
    }
    
    sendTask.resume()
  }
  
  /** Create an address
   */
  func populateAddress() {
    let session = URLSession.shared
    let sendUrl = URL(string: "http://localhost:10553/v0/addresses/")!
    var sendUrlRequest = URLRequest(url: sendUrl, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 30)
    sendUrlRequest.httpMethod = "POST"
    sendUrlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let data = "{}".data(using: .utf8)
    
    let createAddressTask = session.uploadTask(with: sendUrlRequest, from: data) { [weak self] data, urlResponse, error in
      if let error = error {
        return print("ERROR \(error)")
      }
      
      guard let data = data else {
        return print("Expected data")
      }
      
      do {
        guard let json = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] else {
          return print("EXPECTED JSON")
        }
        
        enum JsonAttribute: String {
          case address
          
          var key: String { return rawValue }
        }
        
        guard let address = json[JsonAttribute.address.key] as? String else {
          return print("EXPECTED ADDRESS")
        }
        
        DispatchQueue.main.async { self?.address = address }
      } catch {
        return print(error)
      }
    }
    
    createAddressTask.resume()
  }
}

// MARK: - WalletListener
extension ChainWalletViewController: WalletListener {
  /** Wallet was updated
   */
  func wallet(updated: Wallet) {
    refreshChainBalance()
  }
}
