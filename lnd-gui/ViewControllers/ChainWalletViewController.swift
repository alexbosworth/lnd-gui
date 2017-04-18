//
//  ChainWalletViewController.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 4/17/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Cocoa

class ChainWalletViewController: NSViewController {
  /** User pressed the button to send funds on the chain.
   */
  @IBAction func pressedSendButton(_ button: NSButton) {
  }
  
  @IBOutlet weak var balanceTextField: NSTextField?
  
  @IBOutlet weak var receiveAddressTextField: NSTextField?
  
  @IBOutlet weak var sendToAddressTextField: NSTextField?
  
  @IBOutlet weak var sendAmountTextField: NSTextField?
  
  override func viewDidAppear() {
    super.viewDidAppear()

    populateAddress()
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    // Do view setup here.
  }
}

extension ChainWalletViewController {
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
        
        print("JSON", json)
      } catch {
        return print(error)
      }
    }
    
    createAddressTask.resume()

  }
}
